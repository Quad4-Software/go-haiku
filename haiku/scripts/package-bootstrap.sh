#!/bin/sh
# Package a Haiku bootstrap tarball from a built GOROOT.
# Usage: package-bootstrap.sh [OUT_DIR] [ARCH]
# ARCH defaults to the built toolchain's GOARCH (amd64 or 386).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
OUT_DIR="${1:-$ROOT/haiku/dist}"
ARCH="${2:-}"

VERSION_LINE=$(sed -n '1p' "$ROOT/VERSION" | tr -d '\r')
VERSION=${VERSION_LINE#go}
if [ -z "$VERSION" ] || [ "$VERSION" = "$VERSION_LINE" ]; then
	echo "could not parse VERSION ($VERSION_LINE)" >&2
	exit 1
fi

if [ ! -x "$ROOT/bin/go" ]; then
	echo "missing built toolchain at $ROOT/bin/go" >&2
	exit 1
fi

if [ -z "$ARCH" ]; then
	ARCH=$("$ROOT/bin/go" env GOARCH)
fi
case "$ARCH" in
amd64|386) ;;
*)
	echo "unsupported ARCH=$ARCH (want amd64 or 386)" >&2
	exit 1
	;;
esac

NAME="go-${VERSION}-haiku-${ARCH}-bootstrap"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/$NAME" "$OUT_DIR"
for ent in bin pkg src lib misc VERSION LICENSE README.md go.env; do
	if [ -e "$ROOT/$ent" ]; then
		cp -a "$ROOT/$ent" "$STAGE/$NAME/"
	fi
done
rm -rf "$STAGE/$NAME/pkg/obj" "$STAGE/$NAME/pkg/bootstrap" 2>/dev/null || true

OUT="$OUT_DIR/${NAME}.tbz"
tar -C "$STAGE" -cjf "$OUT" "$NAME"

SUMS="$OUT_DIR/SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
	(cd "$OUT_DIR" && sha256sum ./*.tbz > SHA256SUMS)
elif command -v shasum >/dev/null 2>&1; then
	(cd "$OUT_DIR" && shasum -a 256 ./*.tbz > SHA256SUMS)
else
	echo "need sha256sum or shasum to write $SUMS" >&2
	exit 1
fi

ls -lh "$OUT" "$SUMS"
echo "$OUT"
echo "$SUMS"
