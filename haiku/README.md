# go-haiku

Haiku OS port of the Go toolchain for
[Quad4-Software/go-haiku](https://github.com/Quad4-Software/go-haiku).

Based on [korli/go](https://github.com/korli/go), synced with
[golang/go](https://github.com/golang/go).

## Start here

- [README.md](../README.md) — install and build
- [AGENTS.md](../AGENTS.md) — maintenance / updater agent playbook
- [CHANGES.md](CHANGES.md) — auditable change log (CVEs, CI, port fixes)
- [HAIKU.md](../HAIKU.md) — branches, tags, security overview

## Layout

| Path | Role |
|------|------|
| `haiku/bootstrap.lock` | Pinned bootstrap URL + SHA-256 + allowlist (amd64 + 386) |
| `haiku/assets/` | Haiku logo for docs (see `ATTRIBUTION.txt`) |
| `haiku/scripts/sync-upstream.sh` | Merge an upstream Go ref into a Haiku branch |
| `haiku/scripts/haiku-build.sh` | Build toolchain on Haiku using a bootstrap |
| `haiku/scripts/haiku-cross-386.sh` | Cross-build + package haiku/386 on amd64 Haiku |
| `haiku/scripts/package-bootstrap.sh` | Pack bootstrap tarball + `SHA256SUMS` (amd64 or 386) |
| `haiku/scripts/haiku-smoke.sh` | Post-build smoke tests |
| `haiku/scripts/haiku-net-smoke.sh` | Loopback TCP/UDP smoke |
| `haiku/scripts/qemu-haiku-386-smoke.sh` | QEMU Haiku x86 runtime smoke (prepare + SSH) |
| `haiku/scripts/resolve-bootstrap-url.sh` | Resolve pinned bootstrap URL + hash |
| `haiku/scripts/fetch-bootstrap.sh` | Download, verify SHA-256, extract |
| `haiku/scripts/audit-upstream-cves.sh` | Fail if upstream CVE commits are missing |
| `.github/workflows/haiku-ci.yml` | PR/push/weekly CI (amd64 + QEMU 386) |
| `.github/workflows/haiku-release.yml` | Tag or manual release build (both arches) |
| `.github/workflows/haiku-sync.yml` | Manual upstream sync PR |

## Sync from upstream

```sh
git fetch upstream release-branch.go1.26

./haiku/scripts/sync-upstream.sh \
  --haiku-branch golang-1.26-haiku \
  --upstream-ref release-branch.go1.26
```

Or use Actions: **Haiku Sync**.

## Release

Actions: **Haiku Release**

- `go_version` e.g. `1.26.5` → tag `go1.26.5-haiku.N`
- `bootstrap_url` + `bootstrap_sha256` when overriding the lock
- Publishes amd64 + 386 bootstrap `.tbz` files and combined `SHA256SUMS`

## Bootstrap pin

1. Explicit `HAIKU_BOOTSTRAP_URL` + `HAIKU_BOOTSTRAP_SHA256`
2. `HAIKU_BOOTSTRAP_PIN_TAG` on this repo (needs release `SHA256SUMS`)
3. `haiku/bootstrap.lock` (amd64 keys, or `HAIKU_BOOTSTRAP_ARCH=386` for 386 keys)

After the first Quad4 release, update the lock to your own asset hashes for
both arches.

## CI notes

- Guest amd64: Haiku r1beta5 via `vmactions/haiku-vm`
- Guest 386: QEMU + official `x86_gcc2h` anyboot (not anyvm; no x86 image there yet)
- Cross-compile **to** haiku/386 is supported **on amd64 Haiku** via
  `haiku-cross-386.sh`. Bootstrapping Haiku Go from Linux is not supported.
- On hybrids always `setarch x86` for modern gcc/libs (never `x86_gcc2`)
- CI verifies bootstrap SHA-256 and audits upstream CVE commits after `VERSION`
- Net sockets use Darwin-style cloexec (r1beta5-safe)
