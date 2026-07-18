#!/bin/sh
# QEMU Haiku x86 (GOARCH=386) prepare + runtime smoke wrapper.
# Usage:
#   qemu-haiku-386-smoke.sh prepare
#   qemu-haiku-386-smoke.sh smoke [BOOTSTRAP_TBZ]
#   qemu-haiku-386-smoke.sh all [BOOTSTRAP_TBZ]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
MODE=${1:-all}
BOOTSTRAP=${2:-}

cd "$ROOT"
chmod +x haiku/scripts/qemu_haiku_386.py 2>/dev/null || true

if [ -n "$BOOTSTRAP" ]; then
	exec python3 haiku/scripts/qemu_haiku_386.py "$MODE" --bootstrap "$BOOTSTRAP"
fi
exec python3 haiku/scripts/qemu_haiku_386.py "$MODE"
