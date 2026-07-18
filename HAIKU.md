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

Assets: `go-VERSION-haiku-amd64-bootstrap.tbz` and `SHA256SUMS`

## Remotes

```text
origin    git@github.com:Quad4-Software/go-haiku.git
upstream  https://github.com/golang/go.git
```

Port history started from [korli/go](https://github.com/korli/go). The bootstrap
seed in `haiku/bootstrap.lock` still points at korli's first Haiku release until
Quad4 publishes its own.

## Compatibility

CI targets Haiku **r1beta5**. That image predates `SOCK_CLOEXEC` /
`SOCK_NONBLOCK` as socket type flags and `accept4`. This port creates sockets
the Darwin way (`socket` then `CloseOnExec` / `SetNonblock`).

## Security

See [haiku/CHANGES.md](haiku/CHANGES.md) for the full audit trail.

Short version:

- Bootstrap pin + allowlist: `haiku/bootstrap.lock`
- CVE gate: `./haiku/scripts/audit-upstream-cves.sh`
- Tree includes post-`go1.26.5` fixes for CVE-2026-56853 and CVE-2026-39821
