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
```

OSV (stdlib / toolchain `1.26.5`) reported no known vulns at audit time
(2026-07-17). Post-tag CVEs below were still missing until merged.

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
