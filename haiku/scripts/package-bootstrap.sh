#!/bin/sh
# Package a Haiku amd64 bootstrap tarball from a built GOROOT.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
OUT_DIR="${1:-$ROOT/haiku/dist}"
VERSION_LINE=$(sed -n '1p' "$ROOT/VERSION" | tr -d '\r')
# VERSION file is like: go1.26.5
VERSION=${VERSION_LINE#go}
if [ -z "$VERSION" ] || [ "$VERSION" = "$VERSION_LINE" ]; then
	echo "could not parse VERSION ($VERSION_LINE)" >&2
	exit 1
fi

if [ ! -x "$ROOT/bin/go" ]; then
	echo "missing built toolchain at $ROOT/bin/go" >&2
	exit 1
fi

NAME="go-${VERSION}-haiku-amd64-bootstrap"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/$NAME" "$OUT_DIR"
# Keep the bootstrap lean but complete enough to rebuild and compile programs.
for ent in bin pkg src lib misc VERSION LICENSE README.md go.env; do
	if [ -e "$ROOT/$ent" ]; then
		cp -a "$ROOT/$ent" "$STAGE/$NAME/"
	fi
done
# Drop heavy VCS and local build caches if present.
rm -rf "$STAGE/$NAME/pkg/obj" "$STAGE/$NAME/pkg/bootstrap" 2>/dev/null || true

OUT="$OUT_DIR/${NAME}.tbz"
tar -C "$STAGE" -cjf "$OUT" "$NAME"
ls -lh "$OUT"
echo "$OUT"
