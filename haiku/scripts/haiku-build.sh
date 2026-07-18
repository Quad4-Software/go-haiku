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

# Disable auto toolchain downloads on Haiku.
export GOTOOLCHAIN=local
export GOPROXY=off

# Cap parallelism on Haiku guests unless the caller overrides. High GOMAXPROCS
# plus host-side image cache I/O has produced corrupt .a files in CI.
if [ -z "$JOBS" ]; then
	JOBS=1
fi
export GOMAXPROCS="$JOBS"

clean_build_dirs() {
	# Drop stale outputs. Partial/corrupt pkg archives on Haiku VMs show up as
	# "could not import os (not the start of an archive file ...)" or bootstrap
	# compile exiting 255 mid toolchain1.
	rm -rf "$ROOT/pkg" "$ROOT/bin"
	rm -rf "$GOTMPDIR"
	rm -rf "$GOCACHE"
	mkdir -p "$GOCACHE" "$GOTMPDIR"
}

run_make() {
	cd "$ROOT/src"
	echo "Building with bootstrap $($BOOTSTRAP/bin/go version) (GOMAXPROCS=$GOMAXPROCS)"
	./make.bash
}

clean_build_dirs
if ! run_make; then
	echo "make.bash failed (often flaky Haiku VM I/O). Cleaning and retrying once." >&2
	clean_build_dirs
	run_make
fi

echo "Build OK: $("$ROOT/bin/go" version)"
