#!/bin/sh
# Build the Go toolchain on Haiku using GOROOT_BOOTSTRAP.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BOOTSTRAP="${GOROOT_BOOTSTRAP:-}"
JOBS="${GO_BUILD_JOBS:-}"

if [ -z "$BOOTSTRAP" ]; then
	echo "GOROOT_BOOTSTRAP is required" >&2
	exit 1
fi
if [ ! -x "$BOOTSTRAP/bin/go" ]; then
	echo "bootstrap go missing: $BOOTSTRAP/bin/go" >&2
	exit 1
fi

export GOROOT_BOOTSTRAP="$BOOTSTRAP"
export GOCACHE="${GOCACHE:-/boot/home/user/.cache/go-build}"
export GOTMPDIR="${GOTMPDIR:-/boot/home/user/tmp}"
mkdir -p "$GOCACHE" "$GOTMPDIR"

# Disable auto toolchain downloads on Haiku.
export GOTOOLCHAIN=local
export GOPROXY=off

cd "$ROOT/src"
echo "Building with bootstrap $($BOOTSTRAP/bin/go version)"
if [ -n "$JOBS" ]; then
	export GOMAXPROCS="$JOBS"
fi
./make.bash

echo "Build OK: $("$ROOT/bin/go" version)"
