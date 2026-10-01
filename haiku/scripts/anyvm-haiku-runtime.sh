#!/bin/sh
# Run prebuilt Haiku amd64 binaries in anyvm (QEMU in Docker).
# Default: testdata/runtime-smoke, Haiku-native go/gofmt, optional reticulum-go.
#
# Usage:
#   anyvm-haiku-runtime.sh
#   HAIKU_ANYVM_RETICULUM=/path/to/reticulum-go anyvm-haiku-runtime.sh
#
# Nested KVM hosts that BUG in kvm_arch_vcpu_create should keep the default
# --tcg. Set HAIKU_ANYVM_TCG=0 to try KVM.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CACHE="${HAIKU_ANYVM_CACHE:-${TMPDIR:-/tmp}/haiku-anyvm-cache}"
XFER="${HAIKU_ANYVM_XFER:-${TMPDIR:-/tmp}/haiku-anyvm-xfer}"
IMAGE="${HAIKU_ANYVM_IMAGE:-ghcr.io/anyvm-org/anyvm:latest}"
GO="${HAIKU_ANYVM_GO:-$ROOT/bin/go}"
SMOKE_DIR="$ROOT/haiku/testdata/runtime-smoke"
RETICULUM="${HAIKU_ANYVM_RETICULUM:-}"

if [ ! -x "$GO" ]; then
	echo "need a Linux-hosted go-haiku toolchain at $GO" >&2
	exit 1
fi

mkdir -p "$XFER" "$CACHE"
export GOROOT="$ROOT"
export GOOS=haiku
export GOARCH=amd64
export CGO_ENABLED=0
export GOTOOLCHAIN=local
"$GO" build -C "$SMOKE_DIR" -o "$XFER/hello" .
if [ -x "$ROOT/bin/haiku_amd64/go" ]; then
	cp "$ROOT/bin/haiku_amd64/go" "$XFER/go"
	cp "$ROOT/bin/haiku_amd64/gofmt" "$XFER/gofmt"
elif [ -x "$ROOT/pkg/tool/haiku_amd64/compile" ]; then
	echo "warning: Haiku-native go binary missing, skip go version" >&2
else
	echo "warning: Haiku-native go binary missing, skip go version" >&2
fi
cp "$ROOT/VERSION" "$XFER/VERSION"
if [ -n "$RETICULUM" ] && [ -f "$RETICULUM" ]; then
	cp "$RETICULUM" "$XFER/reticulum-go"
	chmod +x "$XFER/reticulum-go"
fi
chmod +x "$XFER/hello" 2>/dev/null || true
chmod +x "$XFER/go" "$XFER/gofmt" 2>/dev/null || true

cat > "$XFER/run.sh" << 'EOF'
#!/bin/sh
set -eu
echo "=== uname ==="
uname -a
echo "=== hello ==="
chmod +x /boot/home/user/xfer/hello
/boot/home/user/xfer/hello
if [ -x /boot/home/user/xfer/go ]; then
	export GOROOT=/boot/home/user/goroot
	mkdir -p "$GOROOT/bin"
	cp /boot/home/user/xfer/go "$GOROOT/bin/go"
	cp /boot/home/user/xfer/gofmt "$GOROOT/bin/gofmt"
	if [ -f /boot/home/user/xfer/VERSION ]; then
		cp /boot/home/user/xfer/VERSION "$GOROOT/VERSION"
	fi
	chmod +x "$GOROOT/bin/go" "$GOROOT/bin/gofmt"
	export PATH="$GOROOT/bin:$PATH"
	export GOTOOLCHAIN=local
	echo "=== go version ==="
	go version
	go env GOOS GOARCH GOTOOLCHAIN
fi
if [ -x /boot/home/user/xfer/reticulum-go ]; then
	chmod +x /boot/home/user/xfer/reticulum-go
	echo "=== reticulum-go version ==="
	/boot/home/user/xfer/reticulum-go version
	echo "=== reticulum-go self-check quick ==="
	/boot/home/user/xfer/reticulum-go self-check --json --quick
fi
echo ANYVM_HAIKU_OK
EOF
chmod +x "$XFER/run.sh"

TCG_FLAG=--tcg
if [ "${HAIKU_ANYVM_TCG:-1}" = "0" ]; then
	TCG_FLAG=
fi

echo "anyvm xfer $XFER"
if docker info >/dev/null 2>&1; then
	set -- docker
else
	set -- sudo docker
fi
exec "$@" run --rm \
	-v "$XFER:/xfer:ro" \
	-v "$CACHE:/cache" \
	"$IMAGE" \
	--os haiku --release r1beta5 \
	--mem "${HAIKU_ANYVM_MEM:-3072}" --cpu "${HAIKU_ANYVM_CPU:-2}" \
	$TCG_FLAG \
	--cache-dir /cache --data-dir /cache/data \
	--sync scp -v /xfer:/boot/home/user/xfer \
	--vnc off --remote-vnc no \
	--boot-timeout-sec "${HAIKU_ANYVM_BOOT_TIMEOUT:-1800}" \
	-- sh /boot/home/user/xfer/run.sh
