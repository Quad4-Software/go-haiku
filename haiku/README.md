# Haiku port maintenance

## Layout

| Path | Role |
|------|------|
| `haiku/scripts/sync-upstream.sh` | Merge an upstream Go ref into a Haiku branch |
| `haiku/scripts/haiku-build.sh` | Build toolchain on Haiku using a bootstrap |
| `haiku/scripts/package-bootstrap.sh` | Pack a Haiku amd64 bootstrap tarball |
| `haiku/scripts/haiku-smoke.sh` | Post-build smoke tests on Haiku |
| `.github/workflows/haiku-ci.yml` | PR/push CI on Haiku via vmactions |
| `.github/workflows/haiku-release.yml` | Tag or manual release build |
| `.github/workflows/haiku-sync.yml` | Manual upstream sync PR |

## Sync from upstream

Locally:

```sh
# Fetch blobs if this clone used partial clone
git fetch --unshallow korli 2>/dev/null || true
git fetch upstream release-branch.go1.26

./haiku/scripts/sync-upstream.sh \
  --haiku-branch golang-1.26-haiku \
  --upstream-ref release-branch.go1.26
```

Or use Actions: **Haiku Sync** workflow (manual). Pick the Haiku branch and
upstream ref (`release-branch.go1.26` or `go1.26.5`). It opens a PR by default.

Resolve conflicts, push, wait for Haiku CI.

## Release

### Manual (choose version)

Actions: **Haiku Release**

Inputs:

- `go_version` e.g. `1.26.5` (must match `VERSION` after build, or will be written)
- `haiku_revision` e.g. `1` -> tag `go1.26.5-haiku.1`
- `ref` git ref to build (branch/SHA, default current)
- `bootstrap_url` optional seed bootstrap URL
- `run_tests` run smoke tests before packaging

### From a tag

Push a tag matching `go*-haiku.*`:

```sh
git tag go1.26.5-haiku.1
git push origin go1.26.5-haiku.1
```

## Bootstrap seed

First builds need an existing Haiku bootstrap. Default seed is korli's
`go1.26.1-haiku1` asset until this repo publishes its own. After the first
release, point `bootstrap_url` (or the workflow default) at this repo.

## CI notes

- Guest OS: Haiku r1beta5 via `vmactions/haiku-vm`
- Official Go does not cross-compile to Haiku. All builds run in the guest.
- Full `src/run.bash` is long. CI runs `haiku-smoke.sh` by default. Releases
  can enable the same suite.
