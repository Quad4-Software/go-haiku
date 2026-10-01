# go-haiku changes (audit trail)

Living log of intentional differences from upstream `golang/go` and from
`korli/go`. Newest entries first.

Baseline for this document: branch `golang-1.27-haiku`, `VERSION` = `go1.27.1`.

## How to verify

```sh
# Remotes expected:
#   origin    git@github.com:Quad4-Software/go-haiku.git
#   upstream  https://github.com/golang/go.git

git fetch upstream release-branch.go1.27
git fetch upstream tag go1.27.1

# Fail if upstream CVE commits after VERSION are missing from HEAD
./haiku/scripts/audit-upstream-cves.sh upstream/release-branch.go1.27
```

---

## 2026-10-01 — CVE-2026-78660

Merged `upstream/release-branch.go1.27` after `go1.27.1`. The CVE audit in
Haiku CI failed because HEAD did not contain

`072779d815` `net/http/internal/http2: delete malformed framing-related headers`
(Fixes CVE-2026-78660). Cherry-pick is not enough: the audit uses
`git merge-base --is-ancestor`.

Also includes the other post-tag 1.27.1 bugfixes currently on the release
branch (net/http body/trailer, compile, runtime).

---

## 2026-10-01 — Haiku CI SHA pins

GitHub Actions org policy requires every `uses:` to be a full-length commit
SHA. Dependabot left `actions/download-artifact@v8` and `actions/cache@v6`
on floating tags, so Haiku CI aborted at startup (`startup_failure`) before
any job ran.

Pinned:

- `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (v8.0.1)
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` (v6.1.0)

QEMU 386 host deps now install `qemu-system-gui` (VNC display module) and
`vncdotool` via `pipx` so Ubuntu 24.04 runners do not hit PEP 668.

---

## 2026-10-01 — Go 1.27.1

Merged upstream `go1.27.1` onto the Haiku port. New line: `golang-1.27-haiku`.

Port carry-forwards that needed a 1.27-shaped merge:

| Area | Change |
|------|--------|
| `src/runtime/cgo` | Dropped `gcc_haiku_{amd64,386}.c`. Go 1.27 unified unix cgo into `gcc_unix.c` + `pthread_unix.c` + `gcc_libinit_unix.c` (`//go:build unix`, which includes Haiku). The old 2-arg `x_cgo_init` would duplicate symbols and not match the 1.27 4-arg signature. |
| `internal/poll` `writev` | Keep Haiku on the libc `writev` path (`fd_writev_libc.go` + `syscall/linkname_libc.go`). |
| `net` DNS | Use 1.27 `getSystemDNSConfigNamed` with `/boot/system/settings/network/resolv.conf` on Haiku. |
| `cmd/go` cgo | Do not pass `-pthread` on Haiku. |
| `crypto/rand` | Keep Haiku `getentropy` max 256 bytes. |
| sockets | Stay on Darwin-style cloexec (`sys_cloexec.go`). r1beta5 still lacks `SOCK_CLOEXEC` as a socket type flag. |
| bootstrap | korli `go1.26.1-haiku1` still meets `minBootstrap` (`go1.24.6`) until Quad4 publishes 1.27 bootstraps. |

Linux-hosted `GOOS=haiku` compile/link fixes needed after the merge (both arches):

| Area | Change |
|------|--------|
| `runtime` | `libpreinit` + `newosproc0` stub so 1.27 `libInit` links without cgo |
| `internal/syscall/unix` | `AT_FDCWD = -0x64` (386 cannot use the unsigned 32-bit form) |
| `os.stat_haiku` | `time.Unix(ts.Unix())` so 386 Timespec (int32) matches `time.Unix` |
| `syscall` | `//go:linkname` on `sysvicall6` / `rawSysvicall6` (1.27 linker) |
| `cmd/link` x86 | Haiku `R_ADDR` to `SDYNIMPORT` goes through PLT (386 libc pointers) |
| `runtime` 386 | no-op `setldt` and skip `ldt0setup` (TLS comes from runtime_loader) |

`GOOS=haiku GOARCH=amd64` and `GOOS=haiku GOARCH=386` now compile `std` and link `net` hello from Linux. Reticulum-Go `cmd/reticulum-go` (go 1.27.1, `-mod=vendor`, `CGO_ENABLED=0`) also links for both Haiku arches.

Guest runtime (anyvm Haiku r1beta5 x86_64, QEMU TCG when nested KVM cannot create vCPUs): Linux-cross `haiku/amd64` binaries run on the guest. Validated `haiku/testdata/runtime-smoke` (file I/O, loopback TCP, `crypto/rand`), Haiku-native `go version` (GOROOT set for a trimmed `bin/haiku_amd64/go`), and Reticulum-Go `self-check --quick`. Helper: `haiku/scripts/anyvm-haiku-runtime.sh` (default `--tcg`). `HAIKU_QEMU_ACCEL=tcg` forces TCG in the QEMU amd64 helper when `/dev/kvm` is present but broken.

CI, docs, and `sync-upstream.sh` defaults now track `release-branch.go1.27`.

QEMU amd64 guest helper: `haiku/scripts/qemu-haiku-amd64-smoke.sh` (installed r1beta5 x86_64 anyboot).

---

## 2026-07-18 — haiku/386 asm useAbs

Cross-compiling `std` for `haiku/386` failed assembling `runtime.rt0_go`:

```
MOVL $bad_proc_msg<>(SB), 4(SP)
PUSHL $runtime.mainPC(SB)
```

`useAbs` treated every Haiku symbol like a Solaris `libc_` dynimport (never
absolute except `libc_*`). On non-shared `haiku/386` those `$sym` immediates
must be absolute, same as `linux/386`. Fix: only force abs for `libc_*` on
Haiku/Solaris, otherwise keep the usual `I386 && !Flag_shared` rule.

---

## 2026-07-18 — smoke std compile uses -exec=true

`go test std -run=^$` still runs each test binary (init/TestMain). On Haiku,
`runtime.test` exits with status 4 (SIGILL) during that startup. Smoke now
matches `haiku-cross-386.sh`: compile-only via `-exec=$(command -v true)`,
plus `-p 1 -vet=off` to avoid parallel VM flakes and vet noise. On failure the
script greps the log for `FAIL` / `build failed` lines.

---

## 2026-07-18 — smoke std compile logging

`haiku-smoke.sh` runs `go test std -run=^$` from `$GOROOT/src` (outside the
temp hello module) and no longer redirects output to `/dev/null`, so CI shows
compile failures instead of a bare SSH exit 1 after `hello`.

---

## 2026-07-18 — Haiku build flake hardening

`haiku-build.sh` now:

- defaults `GOMAXPROCS` to **1** (override with `GO_BUILD_JOBS`)
- wipes `GOCACHE` as well as `pkg`/`bin`/`GOTMPDIR` before `make.bash`
- retries `make.bash` once after a full clean on failure

This targets intermittent bootstrap `compile` exit 255 during toolchain1 on
vmactions Haiku VMs (host image-cache I/O), not a source regression.

`haiku-cross-386.sh` matches the GOCACHE wipe and default jobs=1.

---

## 2026-07-17 — CI smoke module mode

Smoke helpers create a temp module (`go mod init`) under `GOTMPDIR` before
`go build` / `go run`. Package-path builds outside a module fail with
`go.mod file not found` under module mode.

Also use `mktemp -d "$GOTMPDIR/...XXXXXX"` so temp dirs land on the prepared
Haiku tmp volume.

---

## 2026-07-17 — CI smoke compile fixes

`haiku-smoke.sh` runs `go test -short std -run=^$` (compile-only). That failed on
Haiku with:

| Failure | Fix |
|---------|-----|
| `internal/runtime/wasitest`: `undefined: syscall.Mkfifo` | exclude `haiku` from `nonblock_test.go` build tag (Haiku has no `syscall.Mkfifo`) |
| `runtime`: `constant 2147508224 overflows int32` in `TestBadOpen` | assign Haiku `EBADF` through a non-constant `uint32` then `int32` wrap, and do not negate (runtime returns the BeOS-style bit pattern) |

---

## 2026-07-17 — haiku/386 port

Full `GOOS=haiku GOARCH=386` port for modern 32-bit Haiku (including BeOS-compat
hybrids under `setarch x86`). BeOS R5 / `x86_gcc2` ABI is out of scope.

| Area | Change |
|------|--------|
| dist / platform | `haiku/386` in `cgoEnabled` and `zosarch.go` |
| linker / asm | Haiku ELF dynld, I386 TLS (GS), `movTLSReg` for `Hhaiku` |
| runtime | `sys_haiku_386.s`, `rt0_haiku_386.s`, defs/signal, cgo `gcc_haiku_386.c` |
| syscall / x/sys | `*_haiku_386*` + `mkall.sh` case (ILP32 sizes) |
| bootstrap | `package-bootstrap.sh` arch arg, `haiku-cross-386.sh`, lock keys for 386 |
| CI | amd64 job cross-builds + packages 386; QEMU job boots `x86_gcc2h` anyboot |
| release | publishes amd64 + 386 tbz + combined `SHA256SUMS` |

Known requirements:

- On hybrids run Go under `setarch x86` (modern gcc/libs), never gcc2.
- 386 lock pins stay empty until the first Quad4 386 bootstrap is published.
- `z*_haiku_386.go` should be regenerated on real 32-bit Haiku when headers move.
  Timespec/Timeval/`long` are ILP32 (`time_t` is 32-bit on Haiku i386).
- vmactions/anyvm remain amd64-only; 386 runtime coverage is the QEMU job.
- CI smoke creates a temp module (`go mod init`) then `go build .` / `go run .`
  so module-mode Go does not require a pre-existing go.mod in the work tree.
- Haiku build scripts wipe `pkg`/`bin`/`GOCACHE`, cap `GOMAXPROCS` (default 1),
  retry `make.bash` once on failure, and CI sets `cache-after-prepare: false`
  to avoid corrupt archives under concurrent host image-cache I/O.

---

## 2026-07-17 — security, stability, CI

### Upstream CVE merges (missing from go1.26.5 tag, present on release branch)

| ID | Commit subject | Status in go-haiku |
|----|----------------|--------------------|
| CVE-2026-56853 | `net/http`: header timeout on unencrypted HTTP/2 preface | merged |
| CVE-2026-39821 | `x/net/idna`: reject all-ASCII `xn--` labels | merged |

Merge commit: `Merge upstream/release-branch.go1.26 for CVE-2026-39821 and CVE-2026-56853`

### korli gap (at audit time)

`korli/golang-1.26-haiku` was still at **go1.26.2**, so it lacked go1.26.3 through
go1.26.5 security releases and the two CVEs above. This fork tracks go1.26.5+.

### Runtime / net stability (Haiku r1beta5)

| Change | Why |
|--------|-----|
| Haiku uses `sys_cloexec.go` slow path (not `SOCK_CLOEXEC`/`SOCK_NONBLOCK` socket flags) | r1beta5 CI images predate those socket type flags. Fixes listen/dial failures (`address family not supported`) |
| `runtime.readRandom` opens `/dev/random` with `O_CLOEXEC` | Avoid leaking the entropy FD across `exec` |

### Supply-chain / bootstrap integrity

| Path | Role |
|------|------|
| `haiku/bootstrap.lock` | Pinned seed URL + SHA-256 + allowlisted repos |
| `haiku/scripts/bootstrap-common.sh` | Allowlist + SHA-256 helpers |
| `haiku/scripts/resolve-bootstrap-url.sh` | Resolve pin (override / pin-tag / lock) |
| `haiku/scripts/fetch-bootstrap.sh` | Download, verify hash, extract |
| `haiku/scripts/package-bootstrap.sh` | Also writes `SHA256SUMS` |
| `haiku/scripts/audit-upstream-cves.sh` | CI gate for missing upstream CVE commits |

Seed pin (korli `go1.26.1-haiku1`):

```
SHA-256: b739784c8301a050c6aad7865b883ad06de5a6363fe0f2170cc9b502c728005b
```

### CI / release

- `.github/workflows/haiku-ci.yml`: weekly schedule, CVE audit, verified bootstrap fetch, net smoke
- `.github/workflows/haiku-release.yml`: verified bootstrap, package + upload `SHA256SUMS`
- `haiku/scripts/haiku-net-smoke.sh`: loopback TCP/UDP smoke
- `haiku/scripts/haiku-net-prep.sh`: best-effort loopback prep

### Docs / branding

- Root `README.md`: short install + build instructions
- `haiku/assets/`: Haiku logo (trademark attribution in `ATTRIBUTION.txt`)
- `HAIKU.md`, `haiku/README.md`: maintenance and security notes

---

## Earlier (this fork line)

| Item | Notes |
|------|-------|
| Sync to upstream `go1.26.5` | Via merge of `upstream/go1.26.5` |
| Haiku CI / release / sync workflows | `vmactions/haiku-vm` r1beta5 |
| Packaging scripts | `haiku-build`, `haiku-smoke`, `package-bootstrap`, `sync-upstream` |
| Port base | Inherited from [korli/go](https://github.com/korli/go) `GOOS=haiku` |

Haiku OS port code (syscall, runtime, linker, netpoll, x509 roots, etc.)
originates from korli and is not re-listed file-by-file here. Diff against
`upstream/go1.26.5` for the full OS surface.
