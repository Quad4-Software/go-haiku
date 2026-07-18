#!/bin/sh
# Cross-build a haiku/386 toolchain on an amd64 Haiku host.
# Requires an amd64 Haiku Go bootstrap (GOROOT_BOOTSTRAP).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BOOTSTRAP="${GOROOT_BOOTSTRAP:-}"
OUT_DIR="${1:-$ROOT/haiku/dist}"

if [ -z "$BOOTSTRAP" ]; then
	echo "GOROOT_BOOTSTRAP is required" >&2
	exit 1
fi
if [ ! -x "$BOOTSTRAP/bin/go" ]; then
	echo "bootstrap go missing: $BOOTSTRAP/bin/go" >&2
	exit 1
fi

HOST_GOOS=$("$BOOTSTRAP/bin/go" env GOOS)
HOST_GOARCH=$("$BOOTSTRAP/bin/go" env GOARCH)
if [ "$HOST_GOOS" != "haiku" ] || [ "$HOST_GOARCH" != "amd64" ]; then
	echo "haiku-cross-386.sh expects a haiku/amd64 bootstrap (got ${HOST_GOOS}/${HOST_GOARCH})" >&2
	exit 1
fi

export GOROOT_BOOTSTRAP="$BOOTSTRAP"
export GOCACHE="${GOCACHE:-/boot/home/user/.cache/go-build}"
export GOTMPDIR="${GOTMPDIR:-/boot/home/user/tmp}"
export GOTOOLCHAIN=local
export GOPROXY=off
export GOMAXPROCS="${GO_BUILD_JOBS:-2}"
mkdir -p "$GOCACHE"
rm -rf "$GOTMPDIR"
mkdir -p "$GOTMPDIR"

# Compile-only 386 std check with the host amd64 toolchain before we
# replace bin/ with 386 binaries that cannot run on this host.
if [ -x "$ROOT/bin/go" ]; then
	HOSTGO=$ROOT/bin/go
else
	HOSTGO=$BOOTSTRAP/bin/go
fi
echo "Compile-only haiku/386 std with $($HOSTGO version)"
GOOS=haiku GOARCH=386 "$HOSTGO" test -short -count=1 -exec=true -run=^$ std

# Fresh pkg for the 386 toolchain build (keep amd64 bin/go until make.bash replaces it).
rm -rf "$ROOT/pkg"

cd "$ROOT/src"
echo "Cross-building haiku/386 with bootstrap $($BOOTSTRAP/bin/go version) (GOMAXPROCS=$GOMAXPROCS)"
export GOOS=haiku
export GOARCH=386
./make.bash

# bin/go is now a 386 binary. Do not execute it on amd64 Haiku.
file "$ROOT/bin/go" || true
chmod +x "$ROOT/haiku/scripts/package-bootstrap.sh"
"$ROOT/haiku/scripts/package-bootstrap.sh" "$OUT_DIR" 386

echo "386 bootstrap packaged under $OUT_DIR"
