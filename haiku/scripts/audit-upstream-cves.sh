#!/bin/sh
# Report upstream Go security commits not yet present in this Haiku branch.
# Usage: audit-upstream-cves.sh [upstream-ref]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

UPSTREAM_REF=${1:-upstream/release-branch.go1.26}
VERSION_LINE=$(sed -n '1p' VERSION | tr -d '\r')
BASE_TAG=$VERSION_LINE
MISS_FILE="${TMPDIR:-/tmp}/haiku-cve-missing.$$"
rm -f "$MISS_FILE"
trap 'rm -f "$MISS_FILE"' EXIT

if ! git rev-parse "$UPSTREAM_REF" >/dev/null 2>&1; then
	echo "missing $UPSTREAM_REF (git fetch upstream)" >&2
	exit 1
fi

if ! git rev-parse "$BASE_TAG" >/dev/null 2>&1; then
	echo "local tag $BASE_TAG missing, fetching from upstream"
	git fetch upstream "refs/tags/${BASE_TAG}:refs/tags/${BASE_TAG}" || true
fi

if ! git rev-parse "$BASE_TAG" >/dev/null 2>&1; then
	echo "missing tag $BASE_TAG" >&2
	exit 1
fi

echo "Auditing $UPSTREAM_REF commits after $BASE_TAG for CVE/security markers"
echo "HEAD=$(git rev-parse --short HEAD)"
echo

git log --format='%H %s' "$BASE_TAG..$UPSTREAM_REF" | while read -r hash subject; do
	body=$(git log -1 --format='%b' "$hash")
	text="$subject $body"
	echo "$text" | grep -E 'CVE-[0-9]{4}-[0-9]+' >/dev/null 2>&1 || continue
	if git merge-base --is-ancestor "$hash" HEAD 2>/dev/null; then
		echo "PRESENT $hash $subject"
	else
		echo "MISSING $hash $subject"
		echo "$hash" >> "$MISS_FILE"
	fi
done

if [ -f "$MISS_FILE" ] && [ -s "$MISS_FILE" ]; then
	miss_count=$(wc -l < "$MISS_FILE" | tr -d ' ')
	echo
	echo "FAIL: $miss_count upstream security commit(s) not in HEAD"
	exit 1
fi

echo
echo "OK: no missing CVE/security commits after $BASE_TAG on $UPSTREAM_REF"
