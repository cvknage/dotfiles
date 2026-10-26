package main

import (
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestValidateURL(t *testing.T) {
	good := []string{"https://example.com", "http://localhost:8080/cb?code=1&state=x", "HTTPS://Example.com/a%20b"}
	for _, raw := range good {
		if err := validateURL(raw); err != nil {
			t.Errorf("validateURL(%q) = %v, want nil", raw, err)
		}
	}
	bad := []string{
		"", "file:///etc/passwd", "javascript:alert(1)", "-x", "--help", "mailto:a@b.c", "ftp://example.com",
		"https://", "https:///path", "example.com", "https://exa mple.com", "https://example.com\nfoo",
		"https://example.com\x00", "https://example.com/\"x", "https://example.com/`id`", "https://exämple.com", "https://example.com/" + strings.Repeat("a", maxURLLength),
	}
	for _, raw := range bad {
		if err := validateURL(raw); err == nil {
			t.Errorf("validateURL(%q) = nil, want error", raw)
		}
	}
}

func TestRateLimiter(t *testing.T) {
	var limiter rateLimiter
	now := time.Now()
	for i := 0; i < rateLimitCount; i++ {
		if !limiter.allow(now) {
			t.Fatalf("call %d denied before the limit", i)
		}
	}
	if limiter.allow(now) {
		t.Error("call over the limit was allowed")
	}
	if !limiter.allow(now.Add(rateLimitSpan + time.Second)) {
		t.Error("call after the window was denied")
	}
}

// shortSocketDir is t.TempDir() without the test name: darwin's 104-byte sun_path overflows under
// nix's build dirs otherwise.
func shortSocketDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "oup")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	return dir
}

// recordingOpener is a stand-in host opener that appends its argv to a file, after an optional delay.
func recordingOpener(t *testing.T, delay string) (opener, record string) {
	t.Helper()
	dir := t.TempDir()
	record = filepath.Join(dir, "argv")
	opener = filepath.Join(dir, "opener")
	script := "#!/bin/sh\nsleep " + delay + "\nfor a in \"$@\"; do printf '%s\\n' \"$a\" >> " + record + "; done\n"
	if err := os.WriteFile(opener, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return opener, record
}

func TestOpenPassesURLAsSingleArgv(t *testing.T) {
	opener, record := recordingOpener(t, "0")
	srv := &server{opener: opener}
	raw := "https://example.com/?a=1&b=$(touch$IFSpwned);'id';&&*!"
	if err := srv.open(raw); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(record)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != raw+"\n" {
		t.Errorf("opener argv = %q, want exactly %q", got, raw)
	}
}

func TestOpenRejectsBeforeRunningOpener(t *testing.T) {
	opener, record := recordingOpener(t, "0")
	srv := &server{opener: opener}
	if err := srv.open("file:///etc/passwd"); err == nil {
		t.Fatal("file url accepted")
	}
	if _, err := os.Stat(record); err == nil {
		t.Error("opener ran for a rejected url")
	}
}

func TestRoundTripOverSocket(t *testing.T) {
	opener, record := recordingOpener(t, "0")
	sock := filepath.Join(shortSocketDir(t), "s.sock")
	listener, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go (&server{opener: opener}).acceptLoop(listener)
	t.Setenv(socketEnv, sock)
	if err := openViaProxy([]string{"--", "https://example.com/x"}); err != nil {
		t.Fatal(err)
	}
	if got, _ := os.ReadFile(record); string(got) != "https://example.com/x\n" {
		t.Errorf("recorded %q", got)
	}
	if err := openViaProxy([]string{"javascript:alert(1)"}); err == nil || !strings.Contains(err.Error(), "http") {
		t.Errorf("javascript url error = %v", err)
	}
	if err := openViaProxy([]string{"a", "b"}); err == nil {
		t.Error("two args accepted")
	}
}

func TestClientWithoutSocketEnv(t *testing.T) {
	t.Setenv(socketEnv, "")
	if err := openViaProxy([]string{"https://example.com"}); err == nil {
		t.Error("expected an error with no socket configured")
	}
}

func TestReplySurvivesSlowOpener(t *testing.T) {
	old := requestTimeout
	requestTimeout = 300 * time.Millisecond
	t.Cleanup(func() { requestTimeout = old })
	opener, _ := recordingOpener(t, "1")
	sock := filepath.Join(shortSocketDir(t), "s.sock")
	listener, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go (&server{opener: opener}).acceptLoop(listener)
	t.Setenv(socketEnv, sock)
	if err := openViaProxy([]string{"https://example.com"}); err != nil {
		t.Errorf("slow opener reported as failure: %v", err)
	}
}
