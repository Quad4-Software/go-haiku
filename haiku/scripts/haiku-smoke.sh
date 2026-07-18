#!/bin/sh
# Smoke-test a freshly built Haiku Go toolchain.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
export GOROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"
export GOTOOLCHAIN=local
export GOCACHE="${GOCACHE:-/boot/home/user/.cache/go-build}"
mkdir -p "$GOCACHE"

go version
go env GOOS GOARCH GOROOT

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
cat > main.go <<'EOF'
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Printf("hello from %s/%s\n", runtime.GOOS, runtime.GOARCH)
}
EOF

# Single-file build: avoid "go.mod file not found" from `go build .`
go build -o hello main.go
./hello

# Compile std subset without network.
go test -short -count=1 std -run=^$ >/dev/null

echo "smoke OK"
