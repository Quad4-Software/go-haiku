#!/bin/sh
# Merge an upstream Go ref into a Haiku maintenance branch.
set -eu

HAIKU_BRANCH=golang-1.26-haiku
UPSTREAM_REF=release-branch.go1.26
UPSTREAM_REMOTE=upstream
DRY_RUN=0

usage() {
	cat <<'EOF'
Usage: sync-upstream.sh [options]

Options:
  --haiku-branch NAME   Haiku line branch (default: golang-1.26-haiku)
  --upstream-ref REF    Upstream branch or tag (default: release-branch.go1.26)
  --upstream-remote R   Remote name for golang/go (default: upstream)
  --dry-run             Fetch and show merge plan only
  -h, --help            Show help
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--haiku-branch) HAIKU_BRANCH=$2; shift 2 ;;
		--upstream-ref) UPSTREAM_REF=$2; shift 2 ;;
		--upstream-remote) UPSTREAM_REMOTE=$2; shift 2 ;;
		--dry-run) DRY_RUN=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
	esac
done

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
	echo "missing remote '$UPSTREAM_REMOTE' (expected golang/go)" >&2
	exit 1
fi

echo "Fetching $UPSTREAM_REMOTE $UPSTREAM_REF ..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_REF"

echo "Checking out $HAIKU_BRANCH ..."
git checkout "$HAIKU_BRANCH"

UPSTREAM_SHA=$(git rev-parse FETCH_HEAD)
echo "Upstream tip: $UPSTREAM_SHA ($(git log -1 --oneline FETCH_HEAD))"
echo "Haiku tip:    $(git rev-parse HEAD) ($(git log -1 --oneline HEAD))"

if [ "$DRY_RUN" -eq 1 ]; then
	echo "Dry run: merge would be:"
	echo "  git merge --no-ff -m \"Merge $UPSTREAM_REMOTE/$UPSTREAM_REF into $HAIKU_BRANCH\" FETCH_HEAD"
	git merge-tree "$(git merge-base HEAD FETCH_HEAD)" HEAD FETCH_HEAD | head -n 40 || true
	exit 0
fi

git merge --no-ff -m "Merge $UPSTREAM_REMOTE/$UPSTREAM_REF into $HAIKU_BRANCH" FETCH_HEAD
echo "Merged. Review conflicts if any, then push $HAIKU_BRANCH."
