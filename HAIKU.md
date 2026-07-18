# go-haiku

Haiku OS port of the Go toolchain, based on [korli/go](https://github.com/korli/go)
and kept in sync with [golang/go](https://github.com/golang/go).

## Branches

| Branch | Purpose |
|--------|---------|
| `golang-1.26-haiku` | Active Go 1.26 Haiku line (default) |
| `golang-1.XX-haiku` | Future major lines |
| `golang-master-haiku` | Tracking upstream master (experimental) |

## Tags and releases

Tag format: `goVERSION-haiku.N`

Examples:

- `go1.26.2-haiku.1`
- `go1.26.2-haiku.2` (rebuild / packaging fix)

Release assets:

- `go-VERSION-haiku-amd64-bootstrap.tbz` bootstrap toolchain for Haiku amd64
- Source archive from the tag

## Quick start on Haiku

```sh
curl -fsSL -o go-bootstrap.tbz \
  https://github.com/OWNER/go-haiku/releases/download/go1.26.2-haiku.1/go-1.26.2-haiku-amd64-bootstrap.tbz
mkdir -p ~/go && tar -xjf go-bootstrap.tbz -C ~/go --strip-components=1
export GOROOT=~/go
export PATH="$GOROOT/bin:$PATH"
go version
```

## Maintenance

See [haiku/README.md](haiku/README.md) for upstream sync, CI, and release steps.

## Remotes (local clone)

```text
origin    your GitHub fork (set after you create the repo)
upstream  https://github.com/golang/go.git
korli     https://github.com/korli/go.git
```
