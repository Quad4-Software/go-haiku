#!/bin/sh
# Download a Haiku bootstrap tarball, verify SHA-256, extract to DEST.
# Usage: fetch-bootstrap.sh DEST
set -eu

DEST=${1:-}
if [ -z "$DEST" ]; then
	echo "usage: $0 DEST" >&2
	exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/bootstrap-common.sh"

resolved=$("$SCRIPT_DIR/resolve-bootstrap-url.sh")
url=${resolved%%	*}
sha=${resolved#*	}

haiku_url_allowed "$url"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
tbz="$tmpdir/go-bootstrap.tbz"

echo "Fetching bootstrap: $url"
curl -fsSL -o "$tbz" "$url"
haiku_verify_sha256 "$tbz" "$sha"

mkdir -p "$DEST"
tar -xjf "$tbz" -C "$DEST" --strip-components=1
test -x "$DEST/bin/go"
"$DEST/bin/go" version
echo "bootstrap installed at $DEST"
