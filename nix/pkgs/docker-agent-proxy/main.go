// docker-agent-proxy forwards docker.sock traffic but rejects container/volume creation whose bind-mount source is denied, since the daemon itself can't carry mount-namespace hardening.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var createPathRe = regexp.MustCompile(`^(?:/v[0-9]+\.[0-9]+)?/(containers/create|volumes/create)$`)

func main() {
	var listenPath, upstreamPath, deniedCSV, group string
	flag.StringVar(&listenPath, "listen", "/run/docker-agent-proxy.sock", "unix socket to listen on")
	flag.StringVar(&upstreamPath, "upstream", "/run/docker.sock", "real docker.sock to forward to")
	flag.StringVar(&deniedCSV, "denied", "", "comma-separated list of denied host path prefixes")
	flag.StringVar(&group, "group", "", "group to own the listen socket (default: process group)")
	flag.Parse()

	denied := splitNonEmpty(deniedCSV, ",")
	if len(denied) == 0 {
		log.Println("warning: no denied paths configured, proxy is pass-through only")
	}

	if err := os.Remove(listenPath); err != nil && !os.IsNotExist(err) {
		log.Fatalf("removing stale socket: %v", err)
	}
	ln, err := net.Listen("unix", listenPath)
	if err != nil {
		log.Fatalf("listen %s: %v", listenPath, err)
	}
	if err := os.Chmod(listenPath, 0o660); err != nil {
		log.Fatalf("chmod %s: %v", listenPath, err)
	}
	if group != "" {
		g, err := user.LookupGroup(group)
		if err != nil {
			log.Fatalf("looking up group %s: %v", group, err)
		}
		gid, err := strconv.Atoi(g.Gid)
		if err != nil {
			log.Fatalf("parsing gid for group %s: %v", group, err)
		}
		if err := os.Chown(listenPath, -1, gid); err != nil {
			log.Fatalf("chown %s to group %s: %v", listenPath, group, err)
		}
	}

	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", upstreamPath)
		},
	}
	proxy := httputil.NewSingleHostReverseProxy(&url.URL{Scheme: "http", Host: "docker-agent-proxy"})
	proxy.Transport = transport
	proxy.FlushInterval = -1

	g := &guard{denied: denied, proxy: proxy}
	log.Printf("docker-agent-proxy: %s -> %s (%d denied paths)", listenPath, upstreamPath, len(denied))
	log.Fatal((&http.Server{Handler: g}).Serve(ln))
}

func splitNonEmpty(s, sep string) []string {
	var out []string
	for _, p := range strings.Split(s, sep) {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

type guard struct {
	denied []string
	proxy  *httputil.ReverseProxy
}

func (g *guard) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	m := createPathRe.FindStringSubmatch(r.URL.Path)
	if r.Method != http.MethodPost || m == nil {
		g.proxy.ServeHTTP(w, r)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 10<<20))
	_ = r.Body.Close()
	if err != nil {
		http.Error(w, "docker-agent-proxy: reading request body", http.StatusBadGateway)
		return
	}

	var reason string
	if m[1] == "containers/create" {
		reason = checkContainerCreate(body, g.denied)
	} else {
		reason = checkVolumeCreate(body, g.denied)
	}
	if reason != "" {
		log.Printf("blocked %s %s: %s", r.Method, r.URL.Path, reason)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusForbidden)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"message": "docker-agent-proxy: rejected by agent sandbox policy: " + reason,
		})
		return
	}

	r.Body = io.NopCloser(bytes.NewReader(body))
	r.ContentLength = int64(len(body))
	g.proxy.ServeHTTP(w, r)
}

type createBody struct {
	HostConfig struct {
		Binds  []string `json:"Binds"`
		Mounts []struct {
			Type   string `json:"Type"`
			Source string `json:"Source"`
		} `json:"Mounts"`
	} `json:"HostConfig"`
}

func checkContainerCreate(body []byte, denied []string) string {
	var c createBody
	if err := json.Unmarshal(body, &c); err != nil {
		return "" // malformed body: let the daemon produce its own error
	}
	for _, b := range c.HostConfig.Binds {
		parts := strings.SplitN(b, ":", 3)
		if len(parts) < 2 {
			continue
		}
		if reason := checkSource(parts[0], denied); reason != "" {
			return reason
		}
	}
	for _, mnt := range c.HostConfig.Mounts {
		if mnt.Type != "bind" || mnt.Source == "" {
			continue
		}
		if reason := checkSource(mnt.Source, denied); reason != "" {
			return reason
		}
	}
	return ""
}

type volumeBody struct {
	Driver     string            `json:"Driver"`
	DriverOpts map[string]string `json:"DriverOpts"`
}

func checkVolumeCreate(body []byte, denied []string) string {
	var v volumeBody
	if err := json.Unmarshal(body, &v); err != nil {
		return ""
	}
	if v.Driver != "" && v.Driver != "local" {
		return ""
	}
	device := v.DriverOpts["device"]
	if device == "" {
		return ""
	}
	return checkSource(device, denied)
}

// checkSource also checks the symlink-resolved form, since the bind source may not exist yet.
func checkSource(source string, denied []string) string {
	clean := filepath.Clean(source)
	resolved := clean
	if real, err := filepath.EvalSymlinks(source); err == nil {
		resolved = real
	}
	for _, d := range denied {
		dClean := filepath.Clean(d)
		if underPath(clean, dClean) || underPath(resolved, dClean) {
			return fmt.Sprintf("bind source %q is under denied path %q", source, d)
		}
	}
	return ""
}

func underPath(path, prefix string) bool {
	return path == prefix || strings.HasPrefix(path, prefix+string(filepath.Separator))
}
