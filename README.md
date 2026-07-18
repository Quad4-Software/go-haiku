# go-haiku

<p align="center">
  <a href="https://www.haiku-os.org/">
    <img src="haiku/assets/haiku_logo_black.png" alt="Haiku" width="280"/>
  </a>
</p>

<p align="center">
  Go toolchain for <a href="https://www.haiku-os.org/">Haiku OS</a> (amd64)<br/>
  Based on <a href="https://github.com/korli/go">korli/go</a> · synced with <a href="https://github.com/golang/go">golang/go</a>
</p>

**Current line:** Go **1.26.5** (+ post-tag CVE fixes) on branch `golang-1.26-haiku`

## Install (release)

Prefer a release bootstrap when available:

- [Releases](https://github.com/Quad4-Software/go-haiku/releases)

```sh
# Example once go1.26.5-haiku.1 is published:
curl -fsSL -o go.tbz \
  https://github.com/Quad4-Software/go-haiku/releases/download/go1.26.5-haiku.1/go-1.26.5-haiku-amd64-bootstrap.tbz
curl -fsSL -o SHA256SUMS \
  https://github.com/Quad4-Software/go-haiku/releases/download/go1.26.5-haiku.1/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
mkdir -p ~/go && tar -xjf go.tbz -C ~/go --strip-components=1
export GOROOT=~/go
export PATH="$GOROOT/bin:$PATH"
go version
```

Until the first Quad4 release exists, CI seeds from
[korli go1.26.1-haiku1](https://github.com/korli/go/releases/tag/go1.26.1-haiku1)
(pinned in `haiku/bootstrap.lock`).

## Build from source (on Haiku)

You need an existing Haiku Go bootstrap (`GOROOT_BOOTSTRAP`).

```sh
git clone https://github.com/Quad4-Software/go-haiku.git
cd go-haiku
git checkout golang-1.26-haiku

# Bootstrap: release asset or korli seed (see haiku/bootstrap.lock)
./haiku/scripts/fetch-bootstrap.sh ~/go-bootstrap
export GOROOT_BOOTSTRAP=~/go-bootstrap

./haiku/scripts/haiku-build.sh
export GOROOT=$(pwd)
export PATH="$GOROOT/bin:$PATH"
go version
```

Smoke tests:

```sh
./haiku/scripts/haiku-smoke.sh
./haiku/scripts/haiku-net-smoke.sh
```

## Docs

| Doc | Purpose |
|-----|---------|
| [haiku/CHANGES.md](haiku/CHANGES.md) | What this fork changed (audit trail) |
| [haiku/README.md](haiku/README.md) | Sync, CI, release maintenance |
| [HAIKU.md](HAIKU.md) | Branches, tags, security notes |
| [haiku/bootstrap.lock](haiku/bootstrap.lock) | Pinned bootstrap URL + SHA-256 |

Upstream Go docs still apply for the language and stdlib:
https://go.dev/doc/

## Security / auditability

- Bootstrap downloads are **URL-allowlisted** and **SHA-256 pinned**
- Releases publish `SHA256SUMS`
- CI runs `haiku/scripts/audit-upstream-cves.sh` against `upstream/release-branch.go1.26`
- See [haiku/CHANGES.md](haiku/CHANGES.md) for CVE merges and port fixes

## License

Go source: BSD-style license in [LICENSE](LICENSE).

Haiku logo artwork is a trademark of Haiku, Inc. Attribution in
[haiku/assets/ATTRIBUTION.txt](haiku/assets/ATTRIBUTION.txt).
Marks link to https://www.haiku-os.org/
