// open-url-proxy lets a sandboxed agent open a link in the host browser without any desktop access.
// The unsandboxed side (`serve`) takes one URL per connection and runs the host opener with it as a
// single argv element; the sandboxed side is this binary invoked as xdg-open/open/sensible-browser.
package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	socketEnv      = "OPEN_URL_PROXY_SOCKET"
	maxURLLength   = 4096
	openerTimeout  = 15 * time.Second
	dialTimeout    = 5 * time.Second
	rateLimitCount = 10
	rateLimitSpan  = time.Minute
)

var requestTimeout = 5 * time.Second

func validateURL(raw string) error {
	if raw == "" || len(raw) > maxURLLength {
		return fmt.Errorf("url must be 1-%d bytes", maxURLLength)
	}
	for _, b := range []byte(raw) {
		if b <= ' ' || b >= 0x7f || strings.IndexByte("\"<>\\^`{|}", b) >= 0 {
			return errors.New("url contains characters outside RFC 3986")
		}
	}
	parsed, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("invalid url: %w", err)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return errors.New("only http and https urls are allowed")
	}
	if parsed.Host == "" {
		return errors.New("url has no host")
	}
	return nil
}

type rateLimiter struct {
	mu    sync.Mutex
	times []time.Time
}

func (r *rateLimiter) allow(now time.Time) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	kept := r.times[:0]
	for _, t := range r.times {
		if now.Sub(t) < rateLimitSpan {
			kept = append(kept, t)
		}
	}
	r.times = kept
	if len(r.times) >= rateLimitCount {
		return false
	}
	r.times = append(r.times, now)
	return true
}

type server struct {
	opener  string
	limiter rateLimiter
}

func (s *server) open(raw string) error {
	if err := validateURL(raw); err != nil {
		return err
	}
	if !s.limiter.allow(time.Now()) {
		return errors.New("rate limit exceeded, try again later")
	}
	ctx, cancel := context.WithTimeout(context.Background(), openerTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, s.opener, raw)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("host opener failed: %w", err)
	}
	return nil
}

func (s *server) handle(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(requestTimeout))
	line, err := bufio.NewReaderSize(io.LimitReader(conn, maxURLLength+2), maxURLLength+2).ReadString('\n')
	if err != nil {
		fmt.Fprintf(conn, "error: no complete request line\n")
		return
	}
	raw := strings.TrimSuffix(line, "\n")
	err = s.open(raw)
	_ = conn.SetWriteDeadline(time.Now().Add(requestTimeout))
	if err != nil {
		log.Printf("denied/failed %q: %v", truncate(raw), err)
		fmt.Fprintf(conn, "error: %v\n", err)
		return
	}
	log.Printf("opened %q", truncate(raw))
	fmt.Fprint(conn, "ok\n")
}

func truncate(s string) string {
	if len(s) > 200 {
		return s[:200] + "..."
	}
	return s
}

func exitWhenReparented(originalPPID int, socketPath string) {
	for range time.Tick(2 * time.Second) {
		if os.Getppid() != originalPPID {
			_ = os.Remove(socketPath)
			os.Exit(0)
		}
	}
}

func serve(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ContinueOnError)
	listenPath := fs.String("listen", "", "unix socket path to listen on")
	opener := fs.String("opener", "", "absolute path of the host opener (xdg-open or open)")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *listenPath == "" || !filepath.IsAbs(*opener) {
		return errors.New("-listen and an absolute -opener are required")
	}
	_ = os.Remove(*listenPath)
	// Umask instead of chmod after Listen, which would leave a window for a symlink swap.
	oldUmask := syscall.Umask(0o177)
	listener, err := net.Listen("unix", *listenPath)
	syscall.Umask(oldUmask)
	if err != nil {
		return err
	}
	go exitWhenReparented(os.Getppid(), *listenPath)
	(&server{opener: *opener}).acceptLoop(listener)
	return nil
}

func (s *server) acceptLoop(listener net.Listener) {
	for {
		conn, err := listener.Accept()
		if errors.Is(err, net.ErrClosed) {
			return
		}
		if err != nil {
			log.Printf("accept: %v", err)
			time.Sleep(100 * time.Millisecond)
			continue
		}
		go s.handle(conn)
	}
}

func openViaProxy(args []string) error {
	if len(args) > 0 && args[0] == "--" {
		args = args[1:]
	}
	if len(args) != 1 {
		return errors.New("usage: open <url>")
	}
	socketPath := os.Getenv(socketEnv)
	if socketPath == "" {
		return errors.New(socketEnv + " is not set: no host browser is reachable from this sandbox")
	}
	conn, err := net.DialTimeout("unix", socketPath, dialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(openerTimeout + 2*requestTimeout))
	if _, err := fmt.Fprintf(conn, "%s\n", args[0]); err != nil {
		return err
	}
	reply, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		return err
	}
	if reply != "ok\n" {
		return errors.New(strings.TrimSpace(strings.TrimPrefix(reply, "error: ")))
	}
	return nil
}

func main() {
	log.SetFlags(log.LstdFlags)
	var err error
	switch name := filepath.Base(os.Args[0]); {
	case name == "open-url-proxy" && len(os.Args) > 1 && os.Args[1] == "serve":
		err = serve(os.Args[2:])
	case name == "open-url-proxy":
		err = errors.New("usage: open-url-proxy serve -listen SOCK -opener PATH")
	default:
		err = openViaProxy(os.Args[1:])
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", filepath.Base(os.Args[0]), err)
		os.Exit(1)
	}
}
