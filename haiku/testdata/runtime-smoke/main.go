package main

import (
	"crypto/rand"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

func main() {
	fmt.Printf("hello from %s/%s\n", runtime.GOOS, runtime.GOARCH)
	fmt.Printf("goversion %s\n", runtime.Version())

	dir, err := os.MkdirTemp("", "go-haiku-smoke-*")
	if err != nil {
		fatal("mkdir", err)
	}
	defer os.RemoveAll(dir)

	path := filepath.Join(dir, "note.txt")
	want := []byte("haiku-runtime-ok\n")
	if err := os.WriteFile(path, want, 0o644); err != nil {
		fatal("write", err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		fatal("read", err)
	}
	if string(got) != string(want) {
		fatal("readback", fmt.Errorf("%q != %q", got, want))
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fatal("listen", err)
	}
	addr := ln.Addr().String()
	fmt.Printf("listen %s\n", addr)

	done := make(chan error, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			done <- err
			return
		}
		defer conn.Close()
		buf := make([]byte, 16)
		n, err := conn.Read(buf)
		if err != nil {
			done <- err
			return
		}
		if string(buf[:n]) != "ping" {
			done <- fmt.Errorf("got %q", buf[:n])
			return
		}
		_, err = conn.Write([]byte("pong"))
		done <- err
	}()

	conn, err := net.DialTimeout("tcp", addr, 3*time.Second)
	if err != nil {
		fatal("dial", err)
	}
	if _, err := conn.Write([]byte("ping")); err != nil {
		fatal("write ping", err)
	}
	buf := make([]byte, 16)
	n, err := conn.Read(buf)
	conn.Close()
	if err != nil {
		fatal("read pong", err)
	}
	if string(buf[:n]) != "pong" {
		fatal("pong", fmt.Errorf("got %q", buf[:n]))
	}
	if err := <-done; err != nil {
		fatal("accept", err)
	}
	ln.Close()

	var entropy [32]byte
	if _, err := rand.Read(entropy[:]); err != nil {
		fatal("rand", err)
	}
	fmt.Printf("rand %x\n", entropy[:8])
	fmt.Printf("now %s\n", time.Now().UTC().Format(time.RFC3339))
	fmt.Println("SMOKE_OK")
}

func fatal(what string, err error) {
	fmt.Fprintf(os.Stderr, "smoke %s: %v\n", what, err)
	os.Exit(1)
}
