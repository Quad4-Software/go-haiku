#!/usr/bin/env python3
# Automate Haiku x86 (32-bit hybrid) QEMU install and SSH smoke.
# Host: Linux with qemu-system-i386 (or qemu-system-x86_64), vncdotool, ssh.
#
# Modes:
#   prepare  download ISO, install Haiku to qcow2, enable SSH
#   smoke    boot qcow2, copy bootstrap, run smoke under setarch x86
#   all      prepare (if needed) then smoke

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ISO_NAME = "haiku-r1beta5-x86_gcc2h-anyboot.iso"
ISO_SHA256 = "bd6d5015ce1d94ab2c3fa2f4f685491249938bde9acc55345f76098eb2ea424f"
ISO_URLS = [
    "https://mirrors.rit.edu/haiku/r1beta5/" + ISO_NAME,
    "https://ftp.osuosl.org/pub/haiku/r1beta5/" + ISO_NAME,
    "https://mirrors.tnonline.net/haiku/haiku-release/r1beta5/" + ISO_NAME,
]

VNC_DISPLAY = os.environ.get("HAIKU_QEMU_VNC", "127.0.0.1:1")
SSH_PORT = int(os.environ.get("HAIKU_QEMU_SSH_PORT", "2222"))
SSH_USER = "user"
SSH_PASS = os.environ.get("HAIKU_QEMU_SSH_PASS", "gohaiku")
MEM = os.environ.get("HAIKU_QEMU_MEM", "2048")
DISK_GB = int(os.environ.get("HAIKU_QEMU_DISK_GB", "8"))


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    log("+ " + " ".join(cmd))
    return subprocess.run(cmd, check=True, **kwargs)


def which_qemu() -> str:
    for name in ("qemu-system-i386", "qemu-system-x86_64"):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("need qemu-system-i386 or qemu-system-x86_64")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def download_iso(iso: Path) -> None:
    if iso.is_file() and sha256_file(iso) == ISO_SHA256:
        log(f"ISO OK: {iso}")
        return
    iso.parent.mkdir(parents=True, exist_ok=True)
    tmp = iso.with_suffix(iso.suffix + ".partial")
    last_err = None
    for url in ISO_URLS:
        log(f"Downloading {url}")
        try:
            run(["curl", "-fL", "--retry", "3", "-o", str(tmp), url])
            got = sha256_file(tmp)
            if got != ISO_SHA256:
                raise RuntimeError(f"SHA-256 mismatch want {ISO_SHA256} got {got}")
            tmp.replace(iso)
            log(f"ISO OK: {iso}")
            return
        except Exception as e:
            last_err = e
            log(f"download failed: {e}")
    raise SystemExit(f"failed to download ISO: {last_err}")


def vnc_cmd(*args: str) -> list[str]:
    return ["vncdotool", "-s", VNC_DISPLAY, *args]


def vnc_key(key: str) -> None:
    run(vnc_cmd("key", key))


def vnc_type(text: str, delay: str = "40") -> None:
    run(vnc_cmd("--force-caps", f"--delay={delay}", "type", text))


def vnc_wait_ocr(needle: str, timeout: int = 300) -> None:
    """Best-effort wait: poll screenshots for substring via tesseract if present."""
    deadline = time.time() + timeout
    tmp = Path(tempfile.mkdtemp(prefix="haiku-vnc-"))
    png = tmp / "screen.png"
    has_tesseract = shutil.which("tesseract") is not None
    while time.time() < deadline:
        try:
            subprocess.run(vnc_cmd("capture", str(png)), check=False, capture_output=True)
            if has_tesseract and png.is_file():
                out = subprocess.run(
                    ["tesseract", str(png), "stdout"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if needle.lower() in (out.stdout or "").lower():
                    log(f"OCR found: {needle}")
                    shutil.rmtree(tmp, ignore_errors=True)
                    return
        except Exception:
            pass
        time.sleep(5)
    shutil.rmtree(tmp, ignore_errors=True)
    log(f"OCR wait timed out for {needle!r} (continuing)")


def sleep(sec: float) -> None:
    log(f"sleep {sec}s")
    time.sleep(sec)


def vnc_qemu_display() -> str:
    # vncdotool -s 127.0.0.1:N talks to TCP 5900+N.
    # QEMU wants -display vnc=:N for the same display index.
    if ":" in VNC_DISPLAY:
        return "vnc=:" + VNC_DISPLAY.rsplit(":", 1)[-1]
    return "vnc=:" + VNC_DISPLAY


def start_qemu(
    qemu: str,
    disk: Path,
    iso: Path | None,
    work: Path,
    boot_iso: bool,
) -> subprocess.Popen:
    cmd = [
        qemu,
        "-name",
        "haiku-386",
        "-machine",
        "pc",
        "-m",
        MEM,
        "-smp",
        "2",
        "-accel",
        "tcg,thread=multi",
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
        "-usb",
        "-device",
        "usb-tablet",
        "-rtc",
        "base=localtime",
    ]
    if iso is not None:
        cmd += [
            "-drive",
            f"file={iso},format=raw,if=ide,index=1,media=cdrom,readonly=on",
        ]
        if boot_iso:
            cmd += ["-boot", "order=dc,menu=off"]
        else:
            cmd += ["-boot", "order=c,menu=off"]
    else:
        cmd += ["-boot", "order=c,menu=off"]

    log("+ " + " ".join(cmd))
    return subprocess.Popen(cmd, cwd=str(work))


def qemu_quit(_work: Path, proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=10)


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


def wait_ssh(timeout: int = 600) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = subprocess.run(
            ssh_base() + ["echo", "ssh-ok"],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0 and "ssh-ok" in r.stdout:
            log("SSH ready")
            return
        time.sleep(5)
    raise SystemExit("SSH did not become ready")


def ssh_run(remote: str, check: bool = True) -> subprocess.CompletedProcess:
    return run(ssh_base() + [remote], check=check)


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
    """Open Terminal and configure password SSH on the installed system."""
    sleep(8)
    vnc_key("super-alt-t")
    sleep(5)
    cmds = [
        f"printf '%s\\n%s\\n' '{SSH_PASS}' '{SSH_PASS}' | passwd",
        "pkgman install -y openssh || true",
        "mkdir -p /boot/system/settings/ssh /boot/home/user/config/settings/ssh",
        "test -f /boot/system/settings/ssh/ssh_host_ed25519_key || "
        "ssh-keygen -t ed25519 -f /boot/system/settings/ssh/ssh_host_ed25519_key -N ''",
        "test -f /boot/system/settings/ssh/ssh_host_rsa_key || "
        "ssh-keygen -t rsa -f /boot/system/settings/ssh/ssh_host_rsa_key -N ''",
        "grep -q '^PasswordAuthentication yes' /boot/system/settings/ssh/sshd_config "
        "|| echo PasswordAuthentication yes >> /boot/system/settings/ssh/sshd_config",
        "grep -q '^PermitEmptyPasswords no' /boot/system/settings/ssh/sshd_config "
        "|| echo PermitEmptyPasswords no >> /boot/system/settings/ssh/sshd_config",
        "kill $(ps | grep '[s]shd' | awk '{print $2}') 2>/dev/null || true",
        "sleep 1",
        "/bin/sshd || sshd || true",
    ]
    for c in cmds:
        vnc_type(c, delay="30")
        vnc_key("enter")
        sleep(2 if "pkgman" not in c else 90)


def install_haiku(qemu: str, disk: Path, iso: Path, work: Path) -> None:
    if disk.exists():
        disk.unlink()
    run(["qemu-img", "create", "-f", "qcow2", str(disk), f"{DISK_GB}G"])
    proc = start_qemu(qemu, disk, iso, work, boot_iso=True)
    try:
        log("Waiting for Haiku installer desktop")
        sleep(90)
        vnc_wait_ocr("Trash", timeout=180)
        # Language / first dialog: try advance with tabs + space
        sleep(5)
        for _ in range(3):
            vnc_key("tab")
            sleep(0.3)
        vnc_key("space")
        sleep(10)
        vnc_wait_ocr("Trash", timeout=120)

        log("Opening Terminal")
        vnc_key("super-alt-t")
        sleep(6)
        # Format target disk as BFS
        vnc_type("mkfs -t bfs /dev/disk/ata/0/master/raw gohaiku")
        vnc_key("enter")
        sleep(2)
        vnc_type("yes")
        vnc_key("enter")
        sleep(40)

        log("Launching Installer")
        vnc_type("Installer")
        vnc_key("enter")
        sleep(12)
        # Welcome -> continue
        for _ in range(2):
            vnc_key("tab")
            sleep(0.3)
        vnc_key("space")
        sleep(5)
        # Choose target: move to disk and install
        for _ in range(2):
            vnc_key("tab")
            sleep(0.3)
        vnc_key("space")
        sleep(2)
        vnc_key("down")
        sleep(0.5)
        vnc_key("space")
        sleep(1)
        for _ in range(3):
            vnc_key("tab")
            sleep(0.3)
        vnc_key("space")
        log("Waiting for install to finish")
        sleep(180)
        vnc_wait_ocr("Quit", timeout=300)
        vnc_key("space")
        sleep(5)

        log("Shutting down after install")
        vnc_key("super-alt-t")
        sleep(4)
        vnc_type("shutdown")
        vnc_key("enter")
        sleep(25)
    finally:
        qemu_quit(work, proc)

    # First boot of installed system: enable SSH
    log("First boot: enable SSH")
    proc = start_qemu(qemu, disk, None, work, boot_iso=False)
    try:
        sleep(100)
        vnc_wait_ocr("Trash", timeout=240)
        enable_ssh_via_vnc()
        wait_ssh(timeout=180)
        # Persist sshd start via UserBootscript
        ssh_run(
            "mkdir -p /boot/home/user/config/settings/boot && "
            "grep -q sshd /boot/home/user/config/settings/boot/UserBootscript 2>/dev/null || "
            "echo '/bin/sshd &' >> /boot/home/user/config/settings/boot/UserBootscript"
        )
        ssh_run("sync; shutdown -q", check=False)
        sleep(20)
    finally:
        qemu_quit(work, proc)
    log(f"Prepared disk: {disk}")


def run_smoke(qemu: str, disk: Path, bootstrap: Path, work: Path) -> None:
    if not disk.is_file():
        raise SystemExit(f"missing prepared disk {disk}")
    if not bootstrap.is_file():
        raise SystemExit(f"missing bootstrap {bootstrap}")

    proc = start_qemu(qemu, disk, None, work, boot_iso=False)
    try:
        sleep(80)
        wait_ssh(timeout=420)
        scp_to(bootstrap, "/boot/home/user/go-386-bootstrap.tbz")
        smoke = r"""#!/bin/sh
set -eu
export GOROOT=/boot/home/user/go-386
export PATH="$GOROOT/bin:$PATH"
export GOTOOLCHAIN=local
export GOCACHE=/boot/home/user/.cache/go-build
export GOTMPDIR=/boot/home/user/tmp
mkdir -p "$GOCACHE" "$GOTMPDIR"
go version
go env GOOS GOARCH
test "$(go env GOARCH)" = "386"
TMP=$(mktemp -d "$GOTMPDIR/haiku-smoke.XXXXXX")
cd "$TMP"
cat > main.go <<'EOF'
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Printf("hello from %s/%s\n", runtime.GOOS, runtime.GOARCH)
}
EOF
go mod init haiku.smoke >/dev/null 2>&1
go build -o hello .
./hello | grep 386
go test -short -count=1 std -run=^$ >/dev/null
cat > netcheck.go <<'EOF'
package main

import (
	"fmt"
	"io"
	"net"
	"time"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	must(err)
	defer ln.Close()
	done := make(chan struct{})
	go func() {
		defer close(done)
		c, err := ln.Accept()
		must(err)
		defer c.Close()
		_, err = io.WriteString(c, "ok")
		must(err)
	}()
	c, err := net.DialTimeout("tcp4", ln.Addr().String(), 3*time.Second)
	must(err)
	defer c.Close()
	buf := make([]byte, 8)
	n, err := c.Read(buf)
	must(err)
	if string(buf[:n]) != "ok" {
		panic(buf[:n])
	}
	ua, err := net.ListenPacket("udp4", "127.0.0.1:0")
	must(err)
	defer ua.Close()
	ub, err := net.ListenPacket("udp4", "127.0.0.1:0")
	must(err)
	defer ub.Close()
	_, err = ua.WriteTo([]byte("ping"), ub.LocalAddr())
	must(err)
	_ = ub.SetReadDeadline(time.Now().Add(3 * time.Second))
	n, _, err = ub.ReadFrom(buf)
	must(err)
	if string(buf[:n]) != "ping" {
		panic(buf[:n])
	}
	fmt.Println("netcheck OK")
}
EOF
rm -f main.go
go run .
echo "qemu 386 smoke OK"
"""
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".sh") as f:
            f.write(smoke)
            local_smoke = Path(f.name)
        try:
            scp_to(local_smoke, "/boot/home/user/qemu-386-smoke.sh")
        finally:
            local_smoke.unlink(missing_ok=True)

        remote_cmd = (
            "set -eu; "
            "cd /boot/home/user; "
            "rm -rf go-386; mkdir go-386; "
            "tar -xjf go-386-bootstrap.tbz -C go-386 --strip-components=1; "
            "chmod +x qemu-386-smoke.sh; "
            "if command -v setarch >/dev/null 2>&1 && setarch x86 true 2>/dev/null; then "
            "  setarch x86 ./qemu-386-smoke.sh; "
            "else "
            "  ./qemu-386-smoke.sh; "
            "fi"
        )
        ssh_run(remote_cmd)
        log("386 QEMU smoke passed")
        ssh_run("sync; shutdown -q", check=False)
        sleep(15)
    finally:
        qemu_quit(work, proc)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("mode", choices=("prepare", "smoke", "all"))
    ap.add_argument(
        "--work",
        type=Path,
        default=Path(os.environ.get("HAIKU_QEMU_WORK", "haiku/qemu-386")),
    )
    ap.add_argument(
        "--bootstrap",
        type=Path,
        default=None,
        help="path to go-*-haiku-386-bootstrap.tbz",
    )
    ap.add_argument(
        "--force-prepare",
        action="store_true",
        help="rebuild qcow2 even if it exists",
    )
    args = ap.parse_args()

    root = Path(__file__).resolve().parents[2]
    work = args.work if args.work.is_absolute() else root / args.work
    work.mkdir(parents=True, exist_ok=True)
    iso = work / ISO_NAME
    disk = work / "haiku-r1beta5-x86.qcow2"
    marker = work / "ssh-ready"

    for dep in ("curl", "qemu-img", "vncdotool", "sshpass", "ssh", "scp"):
        if dep == "vncdotool":
            if not shutil.which("vncdotool"):
                raise SystemExit("vncdotool not found (pip install vncdotool)")
        elif not shutil.which(dep):
            raise SystemExit(f"{dep} not found")

    qemu = which_qemu()
    need_prepare = args.mode in ("prepare", "all") and (
        args.force_prepare or not disk.is_file() or not marker.is_file()
    )

    if need_prepare:
        download_iso(iso)
        install_haiku(qemu, disk, iso, work)
        marker.write_text("ok\n", encoding="utf-8")

    if args.mode in ("smoke", "all"):
        boot = args.bootstrap
        if boot is None:
            dist = root / "haiku" / "dist"
            cands = sorted(dist.glob("go-*-haiku-386-bootstrap.tbz"))
            if not cands:
                raise SystemExit("pass --bootstrap or place 386 tbz under haiku/dist")
            boot = cands[-1]
        if not boot.is_absolute():
            boot = root / boot
        run_smoke(qemu, disk, boot, work)


if __name__ == "__main__":
    main()
