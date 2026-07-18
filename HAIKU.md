# go-haiku notes

Companion to the root [README.md](README.md).

## Branches

| Branch | Purpose |
|--------|---------|
| `golang-1.26-haiku` | Active Go 1.26 Haiku line (default) |
| `golang-1.XX-haiku` | Future major lines |
| `golang-master-haiku` | Tracking upstream master (experimental) |

## Tags

Format: `goVERSION-haiku.N` (example: `go1.26.5-haiku.1`)

Assets:

- `go-VERSION-haiku-amd64-bootstrap.tbz`
- `go-VERSION-haiku-386-bootstrap.tbz`
- `SHA256SUMS`

## Remotes

```text
origin    git@github.com:Quad4-Software/go-haiku.git
upstream  https://github.com/golang/go.git
```

Port history started from [korli/go](https://github.com/korli/go). The bootstrap
seed in `haiku/bootstrap.lock` still points at korli's first Haiku release until
Quad4 publishes its own.

## Compatibility

Supported platforms: **`haiku/amd64`** and **`haiku/386`**.

CI targets Haiku **r1beta5**. That image predates `SOCK_CLOEXEC` /
`SOCK_NONBLOCK` as socket type flags and `accept4`. This port creates sockets
the Darwin way (`socket` then `CloseOnExec` / `SetNonblock`).

### 32-bit / hybrid notes

- `haiku/386` targets modern 32-bit Haiku (`setarch x86`), including BeOS-compat
  hybrid images (`x86_gcc2h`).
- Do **not** build or run Go under `x86_gcc2` (BeOS R5 ABI).
- amd64 CI uses `vmactions/haiku-vm`. 386 runtime CI boots the official
  `haiku-r1beta5-x86_gcc2h-anyboot.iso` under QEMU (`haiku/scripts/qemu-haiku-386-smoke.sh`)
  because vmactions/anyvm do not ship Haiku x86 guests yet.
- First 386 bootstrap: on amd64 Haiku run `haiku/scripts/haiku-cross-386.sh`, then
  publish and pin `HAIKU_BOOTSTRAP_URL_386` / `HAIKU_BOOTSTRAP_SHA256_386` in
  `haiku/bootstrap.lock`.
- Regenerate `src/syscall/z*_haiku_386.go` (and matching `x/sys` vendor copies)
  on a real 32-bit Haiku host under `setarch x86` when headers drift.

## Security

See [haiku/CHANGES.md](haiku/CHANGES.md) for the full audit trail.

Short version:

- Bootstrap pin + allowlist: `haiku/bootstrap.lock`
- CVE gate: `./haiku/scripts/audit-upstream-cves.sh`
- Tree includes post-`go1.26.5` fixes for CVE-2026-56853 and CVE-2026-39821
