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

// maxCreateBody caps the create/volume request bodies the guard buffers to inspect. A body over
// this is refused (413) rather than truncated and forwarded: a truncated body would fail the
// denylist parse and sail through unchecked.
const maxCreateBody = 10 << 20

// createRe matches the two body-checked creation endpoints; actionRe matches the endpoints that
// operate on an already-created container, whose stored bind mounts the guard re-checks by
// inspecting it (group 1 is the container id, group 2 the action).
var (
	createRe = regexp.MustCompile(`^(?:/v[0-9]+\.[0-9]+)?/(containers|volumes)/create$`)
	actionRe = regexp.MustCompile(`^(?:/v[0-9]+\.[0-9]+)?/containers/([^/]+)/(start|attach|exec|archive)$`)
)

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

	g := &guard{
		denied:      denied,
		proxy:       proxy,
		inspect:     &http.Client{Transport: transport},
		upstreamURL: "http://docker-agent-proxy",
	}
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
	denied      []string
	proxy       *httputil.ReverseProxy
	inspect     *http.Client
	upstreamURL string
}

func (g *guard) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		if m := createRe.FindStringSubmatch(r.URL.Path); m != nil {
			g.serveCreate(w, r, m[1])
			return
		}
	}
	if m := actionRe.FindStringSubmatch(r.URL.Path); m != nil && g.guardsAction(r.Method, m[2]) {
		g.serveAction(w, r, m[1])
		return
	}
	g.proxy.ServeHTTP(w, r)
}

// guardsAction reports whether an already-created-container endpoint exposes its mounts and so
// needs a re-inspection: start/attach/exec run code against them, and archive reads (GET), writes
// (PUT), or stats (HEAD) files through a bind's host source.
func (g *guard) guardsAction(method, action string) bool {
	switch action {
	case "start", "attach", "exec":
		return method == http.MethodPost
	case "archive":
		return method == http.MethodGet || method == http.MethodPut || method == http.MethodHead
	default:
		return false
	}
}

func (g *guard) serveCreate(w http.ResponseWriter, r *http.Request, kind string) {
	// Read one byte past the cap so an over-limit body is refused, not silently truncated.
	body, err := io.ReadAll(io.LimitReader(r.Body, maxCreateBody+1))
	_ = r.Body.Close()
	if err != nil {
		http.Error(w, "docker-agent-proxy: reading request body", http.StatusBadGateway)
		return
	}
	if len(body) > maxCreateBody {
		log.Printf("blocked %s %s: body exceeds %d bytes", r.Method, r.URL.Path, maxCreateBody)
		http.Error(w, "docker-agent-proxy: request body too large to inspect", http.StatusRequestEntityTooLarge)
		return
	}

	var reason string
	if kind == "containers" {
		reason = g.checkContainerCreate(body)
	} else {
		reason = checkVolumeCreate(body, g.denied)
	}
	if g.rejected(w, r, reason) {
		return
	}

	r.Body = io.NopCloser(bytes.NewReader(body))
	r.ContentLength = int64(len(body))
	g.proxy.ServeHTTP(w, r)
}

func (g *guard) serveAction(w http.ResponseWriter, r *http.Request, id string) {
	reason, err := g.checkContainerRef(id)
	if err != nil {
		// A security check that cannot verify the target must not forward it.
		log.Printf("blocked %s %s: %v", r.Method, r.URL.Path, err)
		http.Error(w, "docker-agent-proxy: cannot verify container mounts", http.StatusBadGateway)
		return
	}
	if g.rejected(w, r, reason) {
		return
	}
	g.proxy.ServeHTTP(w, r)
}

func (g *guard) rejected(w http.ResponseWriter, r *http.Request, reason string) bool {
	if reason == "" {
		return false
	}
	log.Printf("blocked %s %s: %s", r.Method, r.URL.Path, reason)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusForbidden)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"message": "docker-agent-proxy: rejected by agent sandbox policy: " + reason,
	})
	return true
}

// mount is one HostConfig.Mounts / inspect Mounts entry. A Type "volume" entry with the local
// driver and a "device" option is a bind mount created inline -- the same host-path exposure as a
// Type "bind", spelled through the volume API -- so its device must be checked too.
type mount struct {
	Type          string `json:"Type"`
	Source        string `json:"Source"`
	VolumeOptions struct {
		DriverConfig struct {
			Name    string            `json:"Name"`
			Options map[string]string `json:"Options"`
		} `json:"DriverConfig"`
	} `json:"VolumeOptions"`
}

// hostSource returns the host path a mount exposes, or "" if it exposes none. A bind names it
// directly; a local-driver volume carries it in the "device" option (mirrors checkVolumeCreate).
func (m mount) hostSource() string {
	switch m.Type {
	case "bind":
		return m.Source
	case "volume":
		if name := m.VolumeOptions.DriverConfig.Name; name == "" || name == "local" {
			return m.VolumeOptions.DriverConfig.Options["device"]
		}
	}
	return ""
}

// hostConfig is the subset of the Docker HostConfig the guard inspects. It is shared by the
// create body and by the inspect response, whose HostConfig has the same shape.
type hostConfig struct {
	Binds       []string `json:"Binds"`
	Mounts      []mount  `json:"Mounts"`
	VolumesFrom []string `json:"VolumesFrom"`
	Privileged  bool     `json:"Privileged"`
	PidMode     string   `json:"PidMode"`
	IpcMode     string   `json:"IpcMode"`
	UsernsMode  string   `json:"UsernsMode"`
	CapAdd      []string `json:"CapAdd"`
	SecurityOpt []string `json:"SecurityOpt"`
	Devices     []struct {
		PathOnHost string `json:"PathOnHost"`
	} `json:"Devices"`
}

// checkHostConfig rejects a host configuration that would reach a denied path without a
// denylisted bind source. Two families: direct exposure (privileged, host PID/IPC namespace, a
// raw host device) and container escape (host userns, SYS_ADMIN/ALL, a disabled confinement
// layer), which on this rootful daemon is equivalent to reading any denied path. Ordinary
// capabilities (SYS_PTRACE, NET_ADMIN, ...) are left alone. VolumesFrom is not resolved here
// (the caller inspects it); bind/mount sources go through checkSource.
func checkHostConfig(hc hostConfig, denied []string) string {
	if hc.Privileged {
		return "privileged containers can read every denied path"
	}
	if hc.PidMode == "host" {
		return "host PID namespace exposes every process's filesystem view"
	}
	if hc.IpcMode == "host" {
		return "host IPC namespace is not permitted"
	}
	if hc.UsernsMode == "host" {
		return "host user namespace is not permitted"
	}
	if len(hc.Devices) > 0 {
		return fmt.Sprintf("host device %q grants raw access outside the denylist", hc.Devices[0].PathOnHost)
	}
	for _, c := range hc.CapAdd {
		switch strings.TrimPrefix(strings.ToUpper(c), "CAP_") {
		case "SYS_ADMIN", "ALL":
			return fmt.Sprintf("added capability %q enables a container escape", c)
		}
	}
	for _, opt := range hc.SecurityOpt {
		o := strings.ToLower(opt)
		if strings.Contains(o, "unconfined") {
			return fmt.Sprintf("security-opt %q disables a confinement layer", opt)
		}
		if strings.HasPrefix(o, "label") && strings.Contains(o, "disable") {
			return fmt.Sprintf("security-opt %q disables SELinux isolation", opt)
		}
	}
	for _, b := range hc.Binds {
		parts := strings.SplitN(b, ":", 3)
		if len(parts) < 2 {
			continue
		}
		if reason := checkSource(parts[0], denied); reason != "" {
			return reason
		}
	}
	for _, mnt := range hc.Mounts {
		src := mnt.hostSource()
		if src == "" {
			continue
		}
		if reason := checkSource(src, denied); reason != "" {
			return reason
		}
	}
	return ""
}

type createBody struct {
	HostConfig hostConfig `json:"HostConfig"`
}

func (g *guard) checkContainerCreate(body []byte) string {
	var c createBody
	if err := json.Unmarshal(body, &c); err != nil {
		return "" // malformed body: let the daemon produce its own error
	}
	if reason := checkHostConfig(c.HostConfig, g.denied); reason != "" {
		return reason
	}
	// VolumesFrom inherits another container's mounts, so a denied bind reaches this one by
	// reference. Each entry is "name-or-id[:ro|rw]"; verify the referenced container.
	for _, ref := range c.HostConfig.VolumesFrom {
		name := strings.SplitN(ref, ":", 2)[0]
		if name == "" {
			continue
		}
		reason, err := g.checkContainerRef(name)
		if err != nil {
			return fmt.Sprintf("cannot verify volumes-from container %q", name)
		}
		if reason != "" {
			return fmt.Sprintf("volumes-from %q: %s", name, reason)
		}
	}
	return ""
}

// inspectBody is the subset of GET /containers/{id}/json the guard re-checks. The top-level
// Mounts is the daemon's resolved mount list (bind sources already canonicalized), checked
// alongside the stored HostConfig so a config the daemon rewrote is still covered.
type inspectBody struct {
	HostConfig hostConfig `json:"HostConfig"`
	Mounts     []mount    `json:"Mounts"`
}

// checkContainerRef inspects an existing container and re-checks its mounts. This guards the
// start/attach/exec/archive endpoints and closes the create-time TOCTOU: the daemon resolves a
// bind source's symlinks at start, and checkSource resolves them again here, right before it.
func (g *guard) checkContainerRef(id string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, g.upstreamURL+"/containers/"+url.PathEscape(id)+"/json", nil)
	if err != nil {
		return "", err
	}
	resp, err := g.inspect.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	// No such container: let the daemon return its own 404 to the client.
	if resp.StatusCode == http.StatusNotFound {
		return "", nil
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("inspect %s returned status %d", id, resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxCreateBody+1))
	if err != nil {
		return "", err
	}
	var in inspectBody
	if err := json.Unmarshal(data, &in); err != nil {
		return "", err
	}
	if reason := checkHostConfig(in.HostConfig, g.denied); reason != "" {
		return reason, nil
	}
	for _, mnt := range in.Mounts {
		src := mnt.hostSource()
		if src == "" {
			continue
		}
		if reason := checkSource(src, g.denied); reason != "" {
			return reason, nil
		}
	}
	return "", nil
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

// spellings returns a path in both its literal and its resolved form. The denylist and the bind
// source can name the same directory two different ways -- macOS firmlinks turn /var into
// /private/var, and the denylist's spelling is whatever the configuration evaluated to -- so a
// comparison that considers only one spelling silently misses.
func spellings(path string) []string {
	clean := filepath.Clean(path)
	resolved, ok := resolveDeepest(clean)
	if !ok || resolved == clean {
		return []string{clean}
	}
	return []string{clean, resolved}
}

// resolveDeepest resolves the longest existing prefix of path and re-appends the remainder, so a
// bind source that does not exist yet still compares against the denylist's real spelling.
func resolveDeepest(path string) (string, bool) {
	rest := ""
	for current := path; ; {
		if real, err := filepath.EvalSymlinks(current); err == nil {
			return filepath.Join(real, rest), true
		}
		parent := filepath.Dir(current)
		if parent == current {
			return "", false
		}
		rest = filepath.Join(filepath.Base(current), rest)
		current = parent
	}
}

// checkSource rejects a bind source that would expose a denied path, testing containment in
// BOTH directions and in both spellings. The direction matters: a source under a denied path
// is the obvious case, but a source that is an ANCESTOR of one (-v /home/u:/host, or
// -v /:/host) exposes it just as completely, and a one-way prefix test waves it through.
func checkSource(source string, denied []string) string {
	src := spellings(source)
	for _, d := range denied {
		for _, s := range src {
			for _, ds := range spellings(d) {
				if underPath(s, ds) {
					return fmt.Sprintf("bind source %q is under denied path %q", source, d)
				}
				if underPath(ds, s) {
					return fmt.Sprintf("bind source %q contains denied path %q", source, d)
				}
			}
		}
	}
	return ""
}

func underPath(path, prefix string) bool {
	// Clean only leaves a trailing separator on "/", which would make prefix+sep "//" and
	// match nothing -- trim it so every absolute path counts as being under the root.
	prefix = strings.TrimSuffix(prefix, string(filepath.Separator))
	return path == prefix || strings.HasPrefix(path, prefix+string(filepath.Separator))
}
