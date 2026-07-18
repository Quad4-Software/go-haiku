#!/bin/sh
# Smoke-test a freshly built Haiku Go toolchain.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
export GOROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"
export GOTOOLCHAIN=local
export GOPROXY=off
export GOCACHE="${GOCACHE:-/boot/home/user/.cache/go-build}"
export GOTMPDIR="${GOTMPDIR:-/boot/home/user/tmp}"
mkdir -p "$GOCACHE" "$GOTMPDIR"

go version
go env GOOS GOARCH GOROOT

TMP=$(mktemp -d "$GOTMPDIR/haiku-smoke.XXXXXX")
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

# Module mode requires a go.mod for package-path builds (`go build .`).
go mod init haiku.smoke >/dev/null 2>&1
go build -o hello .
./hello

# Compile std tests only. -run=^$ skips test bodies but still executes the
# binary (TestMain/init). On Haiku, runtime.test can die with SIGILL
# (reported as exit status 4). -exec=true matches haiku-cross-386.sh and
# avoids running the binaries after a successful compile.
echo "Compiling std tests (-run=^$ -exec=true)..."
cd "$ROOT/src"
go test -short -count=1 -exec=true std -run=^$

echo "smoke OK"
