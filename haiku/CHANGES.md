# go-haiku changes (audit trail)

Living log of intentional differences from upstream `golang/go` and from
`korli/go`. Newest entries first.

Baseline for this document: branch `golang-1.26-haiku`, `VERSION` = `go1.26.5`,
plus selected post-tag merges from `upstream/release-branch.go1.26`.

## How to verify

```sh
# Remotes expected:
#   origin    git@github.com:Quad4-Software/go-haiku.git
#   upstream  https://github.com/golang/go.git

git fetch upstream release-branch.go1.26
git fetch upstream tag go1.26.5

# Fail if upstream CVE commits after VERSION are missing from HEAD
./haiku/scripts/audit-upstream-cves.sh upstream/release-branch.go1.26

# Bootstrap pin (URL + SHA-256)
cat haiku/bootstrap.lock
./haiku/scripts/resolve-bootstrap-url.sh
HAIKU_BOOTSTRAP_ARCH=386 ./haiku/scripts/resolve-bootstrap-url.sh  # after 386 pin exists

# Platforms
# go tool dist list | grep haiku
# expect haiku/amd64 and haiku/386
```

OSV (stdlib / toolchain `1.26.5`) reported no known vulns at audit time
(2026-07-17). Post-tag CVEs below were still missing until merged.

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
