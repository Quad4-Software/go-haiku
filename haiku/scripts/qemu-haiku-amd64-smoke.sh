#!/bin/sh
# QEMU Haiku x86_64 (GOARCH=amd64) prepare + runtime smoke wrapper.
# Usage:
#   qemu-haiku-amd64-smoke.sh prepare
#   qemu-haiku-amd64-smoke.sh smoke [BOOTSTRAP_TBZ]
#   qemu-haiku-amd64-smoke.sh all [BOOTSTRAP_TBZ]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
MODE=${1:-all}
BOOTSTRAP=${2:-}

cd "$ROOT"
chmod +x haiku/scripts/qemu_haiku_amd64.py 2>/dev/null || true

if [ -n "$BOOTSTRAP" ]; then
	exec python3 haiku/scripts/qemu_haiku_amd64.py "$MODE" --bootstrap "$BOOTSTRAP"
fi
exec python3 haiku/scripts/qemu_haiku_amd64.py "$MODE"
