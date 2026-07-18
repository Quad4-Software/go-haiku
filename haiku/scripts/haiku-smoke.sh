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

# Compile std tests only. Do not execute test binaries:
# -run=^$ still runs init/TestMain (runtime.test dies with SIGILL on Haiku).
# -exec runs the binary under true instead (same idea as haiku-cross-386.sh).
# -p 1 avoids parallel compile flakes on small Haiku VMs.
# -vet=off keeps this a compile smoke, not a vet gate.
TRUE=$(command -v true)
LOG=$GOTMPDIR/haiku-smoke-std.log
echo "Compiling std tests (-run=^$ -exec=$TRUE -p 1 -vet=off)..."
cd "$ROOT/src"
set +e
go test -short -count=1 -p 1 -vet=off -exec="$TRUE" -run=^$ std >"$LOG" 2>&1
status=$?
set -e
# Show the log (CI needs the failure context).
cat "$LOG"
if [ "$status" -ne 0 ]; then
	echo "std compile smoke failed (exit $status). Matching lines:" >&2
	grep -E 'FAIL|exit status|\[build failed\]|undefined:|overflows' "$LOG" >&2 || true
	exit "$status"
fi

echo "smoke OK"
