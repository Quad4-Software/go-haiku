#!/bin/sh
# Best-effort network bring-up helpers for Haiku CI VMs.
set -eu

# Ensure loopback exists. Harmless if already configured.
if command -v ifconfig >/dev/null 2>&1; then
	ifconfig /dev/net/loop 2>/dev/null || true
	ifconfig loop 2>/dev/null || true
fi

# Prefer the pure-Go DNS resolver in constrained VMs.
export GODEBUG="${GODEBUG:+$GODEBUG,}netdns=go"

echo "haiku-net-prep done"
