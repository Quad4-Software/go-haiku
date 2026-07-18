# AGENTS.md — go-haiku maintenance

Instructions for automated or human agents that maintain, update, or release
this repository. Read this before changing the port, syncing upstream, or
touching CI/bootstrap.

## What this repo is

**go-haiku** is a Go toolchain port for **Haiku OS** (`haiku/amd64` and `haiku/386`).

| Fact | Value |
|------|--------|
| GitHub | https://github.com/Quad4-Software/go-haiku |
| Active branch | `golang-1.26-haiku` |
| Upstream | https://github.com/golang/go (`upstream` remote) |
| Port lineage | Started from [korli/go](https://github.com/korli/go) (do **not** add korli as a remote) |
| CI guest (amd64) | Haiku **r1beta5** via `vmactions/haiku-vm` |
| CI guest (386) | QEMU + official Haiku **x86** `x86_gcc2h` anyboot (vmactions/anyvm are amd64-only today) |
| First 386 bootstrap | Cross-built on amd64 Haiku (`haiku/scripts/haiku-cross-386.sh`) |
| BeOS R5 ABI | **Not supported.** On hybrids use modern `setarch x86` (gcc13), never `x86_gcc2` |

Do not treat this like a normal application repo. Most of the tree is upstream
Go. Haiku-specific and fork-ops code lives under `haiku/`, `.github/workflows/haiku-*.yml`,
and `GOOS=haiku` paths under `src/`.

## Remotes (required)

```text
origin    git@github.com:Quad4-Software/go-haiku.git
upstream  https://github.com/golang/go.git
```

- Sync security and point releases from **upstream**, never from korli.
- Keep `origin` as the only push target for Quad4 releases.
- Do not re-add a `korli` remote unless the human explicitly asks.

## Docs map (read these, do not reinvent)

| Path | Use |
|------|-----|
| [README.md](README.md) | User install / build from source |
| [HAIKU.md](HAIKU.md) | Branches, tags, compatibility |
| [haiku/README.md](haiku/README.md) | CI, sync, release ops |
| [haiku/CHANGES.md](haiku/CHANGES.md) | **Audit trail** of intentional fork changes |
| [haiku/bootstrap.lock](haiku/bootstrap.lock) | Pinned bootstrap URL + SHA-256 (amd64 and 386) |

When you land a meaningful port, security, or CI change, **append** to
`haiku/CHANGES.md` in the same change set.

## Standing invariants (do not break)

1. **Bootstrap integrity**
   - Downloads must be allowlisted GitHub **release** URLs.
   - SHA-256 must be verified before extract (`haiku/scripts/fetch-bootstrap.sh`).
   - Pin lives in `haiku/bootstrap.lock`. After the first Quad4 release, update
     the lock to Quad4 assets (keep korli only as temporary seed if needed).
   - Never resolve “latest release” without a pin/tag + `SHA256SUMS`.

2. **CVE currency**
   - After every upstream sync, run:
     `./haiku/scripts/audit-upstream-cves.sh upstream/release-branch.go1.26`
   - CI already runs this. Local agents must run it before declaring a sync done.
   - Merge **post-tag** commits on `upstream/release-branch.go1.N` that fix CVEs
     even when `VERSION` still says `go1.N.M` (until a new point release exists).

3. **Haiku r1beta5 networking**
   - Do **not** put Haiku back on the Linux-style `SOCK_CLOEXEC|SOCK_NONBLOCK`
     socket type fast path (`src/net/sock_cloexec.go`) unless CI has moved to a
     Haiku image that supports those flags and net smoke still passes.
   - Haiku must stay on `src/net/sys_cloexec.go` (Darwin-style slow path).
   - Accept stays on the non-`accept4` path (`internal/poll` cloexec slow path).

4. **`crypto/rand` / entropy**
   - Haiku `getentropy` max buffer is **256** bytes (`src/crypto/internal/sysrand/rand_getrandom.go`).
   - Do not remove that limit.

5. **Auditability**
   - Prefer merge commits from upstream tags/branches over silent cherry-picks
     when possible.
   - Record CVE IDs and reasons in `haiku/CHANGES.md`.

## Routine upkeep tasks

### A. Sync a new upstream point release (e.g. go1.26.6)

```sh
git fetch upstream --tags
git fetch upstream release-branch.go1.26

# Prefer syncing the tag when it exists:
./haiku/scripts/sync-upstream.sh \
  --haiku-branch golang-1.26-haiku \
  --upstream-ref go1.26.6

# Or track the branch tip (includes post-tag CVE fixes):
./haiku/scripts/sync-upstream.sh \
  --haiku-branch golang-1.26-haiku \
  --upstream-ref release-branch.go1.26
```

Then:

1. Resolve conflicts carefully. Prefer upstream for stdlib/compiler unless the
   conflict is in Haiku OS files (`*_haiku*`, `GOOS=haiku` build tags).
2. Update `VERSION` if merging a new point release tag.
3. Run `./haiku/scripts/audit-upstream-cves.sh`.
4. Bump docs/examples that hardcode the Go version if needed.
5. Append `haiku/CHANGES.md`.
6. Push `golang-1.26-haiku` and wait for Haiku CI.
7. Cut a release when CI is green (see below).

### B. Security-only catch-up (no new tag yet)

```sh
git fetch upstream release-branch.go1.26
./haiku/scripts/audit-upstream-cves.sh
# If FAIL: merge upstream/release-branch.go1.26 (or cherry-pick the MISSING commits)
```

Check OSV for stdlib/toolchain at the current `VERSION`, and always check
commits **after** the tag on the release branch.

### C. Release a Haiku bootstrap

Tag format: `goVERSION-haiku.N` (example `go1.26.5-haiku.1`).

Use Actions **Haiku Release** (preferred) or push a matching tag.

Release **must** publish:

- `go-VERSION-haiku-amd64-bootstrap.tbz`
- `go-VERSION-haiku-386-bootstrap.tbz`
- `SHA256SUMS` (both arches)

After the first successful Quad4 release, update `haiku/bootstrap.lock` amd64
and 386 URL/SHA-256 pins (`HAIKU_BOOTSTRAP_URL_386` /
`HAIKU_BOOTSTRAP_SHA256_386`). Allowlist already includes
`Quad4-Software/go-haiku`.

To mint the first 386 bootstrap on an amd64 Haiku host:

```sh
export GOROOT_BOOTSTRAP=~/go-bootstrap   # amd64 Haiku Go
./haiku/scripts/haiku-build.sh           # optional amd64 build + smoke
./haiku/scripts/haiku-cross-386.sh        # compile-only 386 std, then package
```

On 32-bit hybrids, regenerate syscall `z*` files with modern arch only:

```sh
setarch x86
# then src/syscall mkall / go generate paths as documented in haiku/CHANGES.md
```

### D. Smoke expectations on Haiku

```sh
./haiku/scripts/haiku-build.sh
./haiku/scripts/haiku-smoke.sh
./haiku/scripts/haiku-net-smoke.sh
```

Net smoke covers loopback TCP + UDP. Treat net smoke failures as blockers for
releases.

## Partial clone / push pitfalls

This tree is huge (full Go history). Clones with `blob:none` / promisor packs
will **fail to push** with errors like `unable to read <oid>` / `early EOF`.

Before a large first push from a partial clone:

```sh
# Count missing blobs
git rev-list --objects --all --missing=print | grep -c '^?'

# Backfill from upstream (example batch fetch of missing OIDs)
git rev-list --objects --all --missing=print | sed -n 's/^?//p' \
  | xargs -n 40 git fetch --no-filter https://github.com/golang/go.git

# Prefer full clones for maintainers who push.
```

Do not strip history just to make pushes easier unless the human asks.

## Where Haiku port code usually lives

When debugging `GOOS=haiku`:

- `src/runtime/*haiku*`
- `src/syscall/*haiku*`
- `src/net/` (cloexec, cgo DNS, sockopt)
- `src/internal/poll/`, `src/internal/syscall/unix/`
- `src/crypto/x509/root_haiku.go`
- `src/cmd/link/` Haiku ELF bits
- `haiku/scripts/` and `.github/workflows/haiku-*.yml`

Prefer minimal, upstream-shaped patches. Match nearby Go style. Avoid drive-by
refactors of unrelated upstream packages.

## Agent behavior rules

- Do **not** commit, push, or force-push unless the human explicitly asks.
- Do **not** amend commits unless the human explicitly asks and amend rules are met.
- Do **not** generate extra markdown docs unless asked (exception: update
  `haiku/CHANGES.md` when making material changes).
- Do **not** weaken bootstrap allowlists or skip SHA-256 verification “temporarily.”
- Do **not** claim BeOS R5 / `x86_gcc2` ABI support. Haiku 386 means modern `x86`.
- Prefer editing existing Haiku scripts/workflows over inventing parallel tooling.
- Keep comments in Go doc style. No emoji in docs or code.
- When unsure whether a conflict is Haiku-specific, diff against the upstream
  tag and keep Haiku build tags / `*_haiku*` files intact.

## Quick health checklist

```sh
git remote -v
# expect origin + upstream only

sed -n '1p' VERSION
./haiku/scripts/resolve-bootstrap-url.sh
./haiku/scripts/audit-upstream-cves.sh
git status -sb
```

If CI is red on Haiku: inspect `vmactions/haiku-vm` logs, confirm bootstrap
hash, re-run smoke scripts, and check whether a new upstream merge dropped a
Haiku build tag or reintroduced the socket cloexec fast path.
