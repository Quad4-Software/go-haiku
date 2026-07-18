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
| `haiku/bootstrap.lock` | Pinned bootstrap URL + SHA-256 + allowlist |
| `haiku/assets/` | Haiku logo for docs (see `ATTRIBUTION.txt`) |
| `haiku/scripts/sync-upstream.sh` | Merge an upstream Go ref into a Haiku branch |
| `haiku/scripts/haiku-build.sh` | Build toolchain on Haiku using a bootstrap |
| `haiku/scripts/package-bootstrap.sh` | Pack bootstrap tarball + `SHA256SUMS` |
| `haiku/scripts/haiku-smoke.sh` | Post-build smoke tests |
| `haiku/scripts/haiku-net-smoke.sh` | Loopback TCP/UDP smoke |
| `haiku/scripts/resolve-bootstrap-url.sh` | Resolve pinned bootstrap URL + hash |
| `haiku/scripts/fetch-bootstrap.sh` | Download, verify SHA-256, extract |
| `haiku/scripts/audit-upstream-cves.sh` | Fail if upstream CVE commits are missing |
| `.github/workflows/haiku-ci.yml` | PR/push/weekly CI |
| `.github/workflows/haiku-release.yml` | Tag or manual release build |
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
- Publishes bootstrap `.tbz` and `SHA256SUMS`

## Bootstrap pin

1. Explicit `HAIKU_BOOTSTRAP_URL` + `HAIKU_BOOTSTRAP_SHA256`
2. `HAIKU_BOOTSTRAP_PIN_TAG` on this repo (needs release `SHA256SUMS`)
3. `haiku/bootstrap.lock`

After the first Quad4 release, update the lock to your own asset hash.

## CI notes

- Guest: Haiku r1beta5 via `vmactions/haiku-vm`
- No official cross-compile to Haiku. Builds run in the guest.
- CI verifies bootstrap SHA-256 and audits upstream CVE commits after `VERSION`
- Net sockets use Darwin-style cloexec (r1beta5-safe)
