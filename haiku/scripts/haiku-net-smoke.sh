#!/bin/sh
# Extended smoke tests including networking (loopback TCP/UDP).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
export GOROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"
export GOTOOLCHAIN=local
export GOCACHE="${GOCACHE:-/boot/home/user/.cache/go-build}"
mkdir -p "$GOCACHE"

# Base compile/runtime smoke first.
"$ROOT/haiku/scripts/haiku-smoke.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

cat > netcheck.go <<'EOF'
package main

import (
	"fmt"
	"io"
	"net"
	"time"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	must(err)
	defer ln.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		c, err := ln.Accept()
		must(err)
		defer c.Close()
		_, err = io.WriteString(c, "ok")
		must(err)
	}()

	c, err := net.DialTimeout("tcp4", ln.Addr().String(), 3*time.Second)
	must(err)
	defer c.Close()
	buf := make([]byte, 8)
	n, err := c.Read(buf)
	must(err)
	if string(buf[:n]) != "ok" {
		panic(fmt.Sprintf("unexpected payload %q", buf[:n]))
	}

	ua, err := net.ListenPacket("udp4", "127.0.0.1:0")
	must(err)
	defer ua.Close()
	ub, err := net.ListenPacket("udp4", "127.0.0.1:0")
	must(err)
	defer ub.Close()
	_, err = ua.WriteTo([]byte("ping"), ub.LocalAddr())
	must(err)
	_ = ub.SetReadDeadline(time.Now().Add(3 * time.Second))
	n, _, err = ub.ReadFrom(buf)
	must(err)
	if string(buf[:n]) != "ping" {
		panic(fmt.Sprintf("unexpected udp payload %q", buf[:n]))
	}

	fmt.Println("netcheck OK")
}
EOF

go run netcheck.go
echo "net smoke OK"
