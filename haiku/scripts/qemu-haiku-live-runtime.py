#!/usr/bin/env python3
# Boot Haiku r1beta5 live ISO in QEMU and run prebuilt binaries over SSH.
# Does not install to disk. Used to validate Linux-cross-compiled Haiku ELFs.
#
# Usage:
#   qemu-haiku-live-runtime.py BIN [BIN ...]
#
# Prefer haiku/scripts/anyvm-haiku-runtime.sh when QEMU has no VNC module.
#
# Env:
#   HAIKU_QEMU_VNC          default 127.0.0.1:2 (display :1 is often the host)
#   HAIKU_QEMU_SSH_PORT     default 2222
#   HAIKU_QEMU_SSH_PASS     default gohaiku
#   HAIKU_QEMU_MEM          default 2048
#   HAIKU_QEMU_ISO          override ISO path
#   HAIKU_QEMU_ACCEL        tcg or kvm (default: kvm if /dev/kvm is usable)

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ISO_NAME = "haiku-r1beta5-x86_64-anyboot.iso"
ISO_SHA256 = "22ae312a38e98083718b6984186e753d15806bd6ea44542144fdcef42c4dcb69"

VNC_DISPLAY = os.environ.get("HAIKU_QEMU_VNC", "127.0.0.1:2")
SSH_PORT = int(os.environ.get("HAIKU_QEMU_SSH_PORT", "2222"))
SSH_USER = "user"
SSH_PASS = os.environ.get("HAIKU_QEMU_SSH_PASS", "gohaiku")
MEM = os.environ.get("HAIKU_QEMU_MEM", "2048")


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    log("+ " + " ".join(cmd))
    return subprocess.run(cmd, check=True, **kwargs)


def qemu_accel() -> list[str]:
    forced = os.environ.get("HAIKU_QEMU_ACCEL", "").strip().lower()
    if forced in ("tcg", "soft", "emu"):
        return ["-accel", "tcg,thread=multi"]
    if forced == "kvm":
        return ["-accel", "kvm"]
    if os.path.exists("/dev/kvm") and os.access("/dev/kvm", os.R_OK | os.W_OK):
        return ["-accel", "kvm"]
    return ["-accel", "tcg,thread=multi"]


def vnc_cmd(*args: str) -> list[str]:
    return ["vncdotool", "-s", VNC_DISPLAY, *args]


def vnc_key(key: str) -> None:
    run(vnc_cmd("key", key))


def vnc_type(text: str, delay: str = "30") -> None:
    run(vnc_cmd("--force-caps", f"--delay={delay}", "type", text))


def vnc_qemu_display() -> str:
    if ":" in VNC_DISPLAY:
        return "vnc=:" + VNC_DISPLAY.rsplit(":", 1)[-1]
    return "vnc=:" + VNC_DISPLAY


def ssh_base() -> list[str]:
    return [
        "sshpass",
        "-p",
        SSH_PASS,
        "ssh",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "-o",
        "ConnectTimeout=10",
        "-p",
        str(SSH_PORT),
        f"{SSH_USER}@127.0.0.1",
    ]


def wait_ssh(timeout: int = 180) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = subprocess.run(
            ssh_base() + ["echo", "ssh-ok"],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0 and "ssh-ok" in r.stdout:
            log("SSH ready")
            return True
        time.sleep(5)
    return False


def scp_to(local: Path, remote: str) -> None:
    run(
        [
            "sshpass",
            "-p",
            SSH_PASS,
            "scp",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-P",
            str(SSH_PORT),
            str(local),
            f"{SSH_USER}@127.0.0.1:{remote}",
        ]
    )


def enable_ssh_via_vnc() -> None:
    time.sleep(4)
    vnc_key("super-alt-t")
    time.sleep(6)
    cmds = [
        f"printf '%s\\n%s\\n' '{SSH_PASS}' '{SSH_PASS}' | passwd",
        "mkdir -p /boot/system/settings/ssh /boot/home/user/config/settings/ssh",
        "test -f /boot/system/settings/ssh/ssh_host_ed25519_key || "
        "ssh-keygen -t ed25519 -f /boot/system/settings/ssh/ssh_host_ed25519_key -N ''",
        "grep -q '^PasswordAuthentication yes' /boot/system/settings/ssh/sshd_config "
        "|| echo PasswordAuthentication yes >> /boot/system/settings/ssh/sshd_config",
        "kill $(ps | grep '[s]shd' | awk '{print $2}') 2>/dev/null || true",
        "/bin/sshd || sshd || true",
    ]
    for c in cmds:
        vnc_type(c, delay="25")
        vnc_key("enter")
        time.sleep(2)


def start_live(qemu: str, iso: Path, work: Path) -> subprocess.Popen:
    disk = work / "live-overlay.qcow2"
    if disk.exists():
        disk.unlink()
    run(["qemu-img", "create", "-f", "qcow2", str(disk), "4G"])
    cmd = [
        qemu,
        "-name",
        "haiku-live-amd64",
        "-machine",
        "pc",
        "-m",
        MEM,
        "-smp",
        "2",
        *qemu_accel(),
        "-display",
        vnc_qemu_display(),
        "-serial",
        "file:" + str(work / "serial.log"),
        "-netdev",
        f"user,id=n0,hostfwd=tcp:127.0.0.1:{SSH_PORT}-:22",
        "-device",
        "e1000,netdev=n0",
        "-drive",
        f"file={disk},format=qcow2,if=ide,index=0,media=disk",
        "-drive",
        f"file={iso},format=raw,if=ide,index=1,media=cdrom,readonly=on",
        "-boot",
        "order=d,menu=off",
        "-usb",
        "-device",
        "usb-tablet",
        "-rtc",
        "base=localtime",
    ]
    log("+ " + " ".join(cmd))
    return subprocess.Popen(cmd, cwd=str(work))


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: qemu-haiku-live-runtime.py BIN [BIN ...]")
    bins = [Path(a).resolve() for a in sys.argv[1:]]
    for b in bins:
        if not b.is_file():
            raise SystemExit(f"missing binary {b}")
    if not shutil.which("vncdotool"):
        raise SystemExit("vncdotool not found")
    qemu = shutil.which("qemu-system-x86_64")
    if not qemu:
        raise SystemExit("need qemu-system-x86_64")

    root = Path(__file__).resolve().parents[2]
    work = Path(os.environ.get("HAIKU_QEMU_WORK", str(root / "haiku/qemu-amd64")))
    work.mkdir(parents=True, exist_ok=True)
    iso = Path(os.environ.get("HAIKU_QEMU_ISO", str(work / ISO_NAME)))
    if not iso.is_file():
        raise SystemExit(f"missing ISO {iso}")

    proc = start_live(qemu, iso, work)
    log_path = work / "live-runtime.log"
    try:
        log("Waiting for live desktop")
        time.sleep(75)
        enable_ssh_via_vnc()
        if not wait_ssh(timeout=120):
            log("SSH not ready, retrying VNC sshd")
            enable_ssh_via_vnc()
            if not wait_ssh(timeout=120):
                serial = (work / "serial.log").read_text(errors="replace")[-4000:]
                log("serial tail:\n" + serial)
                raise SystemExit("SSH did not become ready on live ISO")

        remote_cmds = []
        for b in bins:
            dest = "/boot/home/user/" + b.name
            scp_to(b, dest)
            run(ssh_base() + [f"chmod +x {dest}"])
            remote_cmds.append(dest)

        script = "set -eu\n"
        script += "uname -a || true\n"
        for dest in remote_cmds:
            name = Path(dest).name
            if "hello" in name:
                script += f"{dest}\n"
            elif "reticulum" in name:
                script += (
                    f"{dest} version || {dest} --version || {dest} -h | head -20\n"
                    f"{dest} self-check --json --quick || true\n"
                )
            else:
                script += f"{dest} || true\n"
        script += "echo live-runtime OK\n"
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".sh") as f:
            f.write(script)
            local_script = Path(f.name)
        try:
            scp_to(local_script, "/boot/home/user/live-runtime.sh")
        finally:
            local_script.unlink(missing_ok=True)
        run(ssh_base() + ["chmod +x /boot/home/user/live-runtime.sh && /boot/home/user/live-runtime.sh"])
        log("live runtime smoke passed")
        log_path.write_text("ok\n", encoding="utf-8")
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=10)


if __name__ == "__main__":
    main()
