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
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// maxCreateBody caps the create/volume request bodies the guard buffers to inspect. A body over
// this is refused (413) rather than truncated and forwarded: a truncated body would fail the
// denylist parse and sail through unchecked. Inspect responses (container/volume/exec) share the
// same cap: they're read from a daemon this proxy trusts, but an unbounded read still isn't safe.
const maxCreateBody = 10 << 20

// versionPrefixRe strips a leading API version component before route matching. Confirmed live
// against the real daemon: its router matches the route pattern "/v{version:[0-9.]+}" -- any
// nonempty run of digits and dots, not just a well-formed MAJOR.MINOR pair -- and routes even a
// malformed version like "/v1", "/v.44", or "/v1..44" through to its own version-range check
// (rejected there with the daemon's own "too old"/"too new" error, not ours). A regex requiring at
// least one dot missed every one of those, forwarding the request unchecked; it only did no harm
// because this daemon's configured version window happens to exclude every dot-less value, which
// is the daemon's business, not a guarantee this proxy controls. Matching the daemon's true accepted
// charset removes that dependency. Stripping first and erring permissive means a version the daemon
// goes on to reject for its own reasons still gets checked by this guard first.
var versionPrefixRe = regexp.MustCompile(`^/v[0-9.]+`)

func stripVersion(p string) string {
	return versionPrefixRe.ReplaceAllString(p, "")
}

// createRe matches the two body-checked creation endpoints. actionRe and attachWSRe match the
// endpoints that operate on an already-created container, whose stored bind mounts the guard
// re-checks by inspecting it (group 1 is the container id, group 2 of actionRe the action).
// execStartRe matches the endpoint that actually runs an already-registered exec instance --
// distinct from POST /containers/{id}/exec, which only registers one. swarmRe and pluginRe match
// endpoints rejected outright in ServeHTTP: swarm/service specs and plugin installs can declare
// host mounts, devices, and capabilities of their own, entirely outside this guard's per-container
// checks, and this sandbox has no legitimate use for either. All match the version-stripped,
// cleaned path, never the raw request path.
var (
	createRe    = regexp.MustCompile(`^/(containers|volumes)/create$`)
	actionRe    = regexp.MustCompile(`^/containers/([^/]+)/(start|restart|attach|exec|archive)$`)
	attachWSRe  = regexp.MustCompile(`^/containers/([^/]+)/attach/ws$`)
	execStartRe = regexp.MustCompile(`^/exec/([^/]+)/start$`)
	swarmRe     = regexp.MustCompile(`^/(?:swarm/(?:init|join)|services/create|services/[^/]+/update)$`)
	pluginRe    = regexp.MustCompile(`^/plugins/(?:pull|[^/]+/enable)$`)
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
		denied: denied,
		proxy:  proxy,
		// A hung daemon must not hang the proxy indefinitely. This is a per-request timeout, not
		// a budget for the whole guard decision -- a create referencing several named volumes
		// issues one inspect round trip per name, each carrying its own deadline.
		inspect:     &http.Client{Transport: transport, Timeout: 10 * time.Second},
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
	// path.Clean, not filepath.Clean: this is a URL path (always "/"-separated), and cleaning
	// before matching means a redundant-slash or dot-segment spelling can't dodge a route this
	// guard would otherwise catch, independent of whatever the daemon's own router tolerates.
	cleaned := path.Clean(r.URL.Path)
	stripped := stripVersion(cleaned)
	versionPrefix := cleaned[:len(cleaned)-len(stripped)]

	if r.Method == http.MethodPost && swarmRe.MatchString(stripped) {
		g.rejected(w, r, "swarm mode is not permitted in the agent sandbox")
		return
	}
	if r.Method == http.MethodPost && pluginRe.MatchString(stripped) {
		g.rejected(w, r, "plugin installation is not permitted in the agent sandbox")
		return
	}
	if r.Method == http.MethodPost {
		if m := createRe.FindStringSubmatch(stripped); m != nil {
			g.serveCreate(w, r, m[1])
			return
		}
		if m := execStartRe.FindStringSubmatch(stripped); m != nil {
			g.serveExecStart(w, r, m[1])
			return
		}
	}
	if m := actionRe.FindStringSubmatch(stripped); m != nil && g.guardsAction(r.Method, m[2]) {
		g.serveAction(w, r, m[1], stripped, versionPrefix)
		return
	}
	if r.Method == http.MethodGet {
		if m := attachWSRe.FindStringSubmatch(stripped); m != nil {
			g.serveAction(w, r, m[1], stripped, versionPrefix)
			return
		}
	}
	g.proxy.ServeHTTP(w, r)
}

// guardsAction reports whether an already-created-container endpoint exposes its mounts and so
// needs a re-inspection: start/restart/attach/exec run code against them, and archive reads (GET),
// writes (PUT), or stats (HEAD) files through a bind's host source. restart matters as much as
// start: it reactivates a stopped container's mounts the same way, and the daemon re-resolves bind
// sources at that point exactly as it does at start.
func (g *guard) guardsAction(method, action string) bool {
	switch action {
	case "start", "restart", "attach", "exec":
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
	forward := body
	var err2 error
	if kind == "containers" {
		reason, forward, err2 = g.checkContainerCreate(body)
	} else {
		reason = checkVolumeCreate(body, g.denied)
	}
	if err2 != nil {
		log.Printf("blocked %s %s: %v", r.Method, r.URL.Path, err2)
		http.Error(w, "docker-agent-proxy: cannot verify referenced resource", http.StatusBadGateway)
		return
	}
	if g.rejected(w, r, reason) {
		return
	}

	r.Body = io.NopCloser(bytes.NewReader(forward))
	r.ContentLength = int64(len(forward))
	// The body was read to completion and ContentLength set explicitly above; a stale inherited
	// chunked Transfer-Encoding would now conflict with it.
	r.TransferEncoding = nil
	g.proxy.ServeHTTP(w, r)
}

// serveAction re-checks an existing container's mounts and forwards against its resolved Id, not
// the id/name the client sent. Forwarding by id closes a second gap beyond the mount re-check
// itself: a rename onto the checked name, in the moment between this check and the daemon
// receiving the forwarded request, could otherwise substitute a different container.
func (g *guard) serveAction(w http.ResponseWriter, r *http.Request, id, strippedPath, versionPrefix string) {
	resolvedID, reason, err := g.checkContainerRef(id)
	if err != nil {
		// A security check that cannot verify the target must not forward it.
		log.Printf("blocked %s %s: %v", r.Method, r.URL.Path, err)
		http.Error(w, "docker-agent-proxy: cannot verify container mounts", http.StatusBadGateway)
		return
	}
	if g.rejected(w, r, reason) {
		return
	}
	if resolvedID != "" {
		r.URL.Path = versionPrefix + rewriteContainerID(strippedPath, id, resolvedID)
		r.URL.RawPath = ""
	}
	g.proxy.ServeHTTP(w, r)
}

// rewriteContainerID replaces the id/name segment of an already-matched "/containers/<id>/..."
// path with the container's resolved Id.
func rewriteContainerID(strippedPath, oldID, resolvedID string) string {
	return "/containers/" + resolvedID + strings.TrimPrefix(strippedPath, "/containers/"+oldID)
}

// serveExecStart re-checks the mounts of the container an exec instance belongs to before letting
// the exec actually run. POST /containers/{id}/exec (guarded via actionRe) only registers the
// exec and is not itself where code runs; POST /exec/{execId}/start is.
func (g *guard) serveExecStart(w http.ResponseWriter, r *http.Request, execID string) {
	var ex execInspectBody
	ok, err := g.inspectUpstream("/exec/"+url.PathEscape(execID)+"/json", &ex)
	if err != nil {
		log.Printf("blocked %s %s: %v", r.Method, r.URL.Path, err)
		http.Error(w, "docker-agent-proxy: cannot verify exec target", http.StatusBadGateway)
		return
	}
	if !ok {
		// No such exec: let the daemon produce its own 404.
		g.proxy.ServeHTTP(w, r)
		return
	}
	if ex.ContainerID == "" {
		// A 200 response naming no owning container is anomalous, not a legitimate pass-through
		// case -- fail closed the same as any other unverifiable target.
		log.Printf("blocked %s %s: exec inspect returned no ContainerID", r.Method, r.URL.Path)
		http.Error(w, "docker-agent-proxy: cannot verify exec target", http.StatusBadGateway)
		return
	}
	_, reason, err := g.checkContainerRef(ex.ContainerID)
	if err != nil {
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
// capabilities (SYS_PTRACE, NET_ADMIN, ...) are left alone. VolumesFrom and named-volume
// references are not resolved here (the caller inspects them); bind/mount sources go through
// checkSource.
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

// namedVolumeRefs extracts the volume names hc's Binds and Mounts reference by name, deduplicated
// so a name repeated across entries is resolved once. A Binds entry whose source isn't an absolute
// path is, by Docker's own convention, a named volume; a Mounts entry of Type "volume" names one
// directly. A name is resolved even when its Mounts entry also carries an inline VolumeOptions
// device: for a volume that already exists, Docker's volume store returns the existing volume and
// silently ignores the client-supplied driver opts, so a harmless-looking inline device is no
// guarantee the daemon actually uses it -- only checking the existing volume's own recorded device
// (via checkVolumeRef) does.
func namedVolumeRefs(hc hostConfig) []string {
	seen := map[string]bool{}
	var names []string
	add := func(name string) {
		if name == "" || seen[name] {
			return
		}
		seen[name] = true
		names = append(names, name)
	}
	for _, b := range hc.Binds {
		parts := strings.SplitN(b, ":", 3)
		if len(parts) < 2 || filepath.IsAbs(parts[0]) {
			continue
		}
		add(parts[0])
	}
	for _, mnt := range hc.Mounts {
		if mnt.Type == "volume" {
			add(mnt.Source)
		}
	}
	return names
}

// checkHostConfigAndVolumes runs checkHostConfig and additionally resolves any Binds/Mounts entry
// that names an existing volume rather than a host path. A named volume created with
// driver_opts.device=<host-path> -- for instance before this proxy existed, or by root outside the
// sandbox -- is a bind mount in disguise, the same way an inline VolumeOptions.device is; a bare
// reference to it by name skips checkHostConfig's source checks entirely without this.
func (g *guard) checkHostConfigAndVolumes(hc hostConfig) (string, error) {
	if reason := checkHostConfig(hc, g.denied); reason != "" {
		return reason, nil
	}
	for _, name := range namedVolumeRefs(hc) {
		reason, err := g.checkVolumeRef(name)
		if err != nil {
			return "", fmt.Errorf("cannot verify volume %q: %w", name, err)
		}
		if reason != "" {
			return fmt.Sprintf("volume %q: %s", name, reason), nil
		}
	}
	return "", nil
}

type createBody struct {
	HostConfig hostConfig `json:"HostConfig"`
}

// checkContainerCreate checks a /containers/create body and returns the body to forward, which is
// the original body unless VolumesFrom needed rewriting (see below). A malformed or reason-free
// result always forwards something: the caller relies on a non-nil forward body whenever reason
// == "" && err == nil.
func (g *guard) checkContainerCreate(body []byte) (reason string, forward []byte, err error) {
	var c createBody
	if err := json.Unmarshal(body, &c); err != nil {
		return "", body, nil // malformed body: let the daemon produce its own error
	}
	reason, err = g.checkHostConfigAndVolumes(c.HostConfig)
	if err != nil {
		return "", nil, err
	}
	if reason != "" {
		return reason, nil, nil
	}

	// VolumesFrom inherits another container's mounts, so a denied bind reaches this one by
	// reference. Each entry is "name-or-id[:ro|rw]"; verify the referenced container and rewrite
	// the reference to its resolved Id before forwarding -- otherwise a rename onto the checked
	// name, in the gap between this check and the daemon processing the create, could substitute a
	// different, dirty container the same way an unpinned action endpoint could (see serveAction).
	resolved := append([]string(nil), c.HostConfig.VolumesFrom...)
	changed := false
	for i, ref := range c.HostConfig.VolumesFrom {
		name, rest, hasMode := strings.Cut(ref, ":")
		if name == "" {
			continue
		}
		resolvedID, reason, err := g.checkContainerRef(name)
		if err != nil {
			return fmt.Sprintf("cannot verify volumes-from container %q", name), nil, nil
		}
		if reason != "" {
			return fmt.Sprintf("volumes-from %q: %s", name, reason), nil, nil
		}
		if resolvedID != "" && resolvedID != name {
			if hasMode {
				resolved[i] = resolvedID + ":" + rest
			} else {
				resolved[i] = resolvedID
			}
			changed = true
		}
	}
	if !changed {
		return "", body, nil
	}
	rewritten, err := rewriteVolumesFrom(body, resolved)
	if err != nil {
		return fmt.Sprintf("cannot rewrite volumes-from references: %v", err), nil, nil
	}
	return "", rewritten, nil
}

// rewriteVolumesFrom replaces HostConfig.VolumesFrom in a create body with resolved values,
// leaving every other field's original bytes untouched -- a typed round trip through createBody
// would silently drop every field this guard doesn't model (Image, Cmd, Env, ...).
func rewriteVolumesFrom(body []byte, resolved []string) ([]byte, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(body, &top); err != nil {
		return nil, err
	}
	hcRaw, ok := top["HostConfig"]
	if !ok {
		return body, nil
	}
	var hc map[string]json.RawMessage
	if err := json.Unmarshal(hcRaw, &hc); err != nil {
		return nil, err
	}
	encoded, err := json.Marshal(resolved)
	if err != nil {
		return nil, err
	}
	hc["VolumesFrom"] = encoded
	hcEncoded, err := json.Marshal(hc)
	if err != nil {
		return nil, err
	}
	top["HostConfig"] = hcEncoded
	return json.Marshal(top)
}

// inspectBody is the subset of GET /containers/{id}/json the guard re-checks. The top-level
// Mounts is the daemon's resolved mount list (bind sources already canonicalized), checked
// alongside the stored HostConfig so a config the daemon rewrote is still covered. Id is the
// container's canonical id, used to pin the forwarded request once the check passes.
type inspectBody struct {
	ID         string     `json:"Id"`
	HostConfig hostConfig `json:"HostConfig"`
	Mounts     []mount    `json:"Mounts"`
}

// checkContainerRef inspects an existing container and re-checks its mounts, returning its
// canonical Id alongside the verdict. This guards the start/restart/attach/exec/archive endpoints
// (and, indirectly, exec-start and volumes-from) and closes the create-time TOCTOU: the daemon
// resolves a bind source's symlinks at start, and checkSource resolves them again here, right
// before it. An empty id with no error and no rejection means no such container -- the daemon
// returns its own 404.
func (g *guard) checkContainerRef(id string) (resolvedID, reason string, err error) {
	var in inspectBody
	ok, err := g.inspectUpstream("/containers/"+url.PathEscape(id)+"/json", &in)
	if err != nil {
		return "", "", err
	}
	if !ok {
		return "", "", nil
	}
	reason, err = g.checkHostConfigAndVolumes(in.HostConfig)
	if err != nil {
		return "", "", err
	}
	if reason != "" {
		return in.ID, reason, nil
	}
	for _, mnt := range in.Mounts {
		src := mnt.hostSource()
		if src == "" {
			continue
		}
		if reason := checkSource(src, g.denied); reason != "" {
			return in.ID, reason, nil
		}
	}
	return in.ID, "", nil
}

// volumeInspectBody is the subset of GET /volumes/{name} the guard checks when a container
// references an existing named volume rather than creating one inline.
type volumeInspectBody struct {
	Driver  string            `json:"Driver"`
	Options map[string]string `json:"Options"`
}

// checkVolumeRef inspects an existing named volume and checks its device option the same way
// checkVolumeCreate checks one being created inline. An empty result with no error means the
// volume doesn't exist or exposes no host device.
func (g *guard) checkVolumeRef(name string) (string, error) {
	var v volumeInspectBody
	ok, err := g.inspectUpstream("/volumes/"+url.PathEscape(name), &v)
	if err != nil {
		return "", err
	}
	if !ok {
		return "", nil
	}
	if v.Driver != "" && v.Driver != "local" {
		return "", nil
	}
	device := v.Options["device"]
	if device == "" {
		return "", nil
	}
	return checkSource(device, g.denied), nil
}

// execInspectBody is the subset of GET /exec/{execId}/json the guard needs: which container an
// exec instance belongs to.
type execInspectBody struct {
	ContainerID string `json:"ContainerID"`
}

// inspectUpstream GETs an upstream inspect endpoint and decodes its JSON body into out. It
// reports ok=false, with no error, when the resource doesn't exist, so the caller can let the
// daemon produce its own 404 rather than rejecting an unverifiable target.
func (g *guard) inspectUpstream(reqPath string, out any) (ok bool, err error) {
	req, err := http.NewRequest(http.MethodGet, g.upstreamURL+reqPath, nil)
	if err != nil {
		return false, err
	}
	resp, err := g.inspect.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return false, nil
	}
	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("inspect %s returned status %d", reqPath, resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxCreateBody+1))
	if err != nil {
		return false, err
	}
	if len(data) > maxCreateBody {
		return false, fmt.Errorf("inspect %s response exceeds %d bytes", reqPath, maxCreateBody)
	}
	if err := json.Unmarshal(data, out); err != nil {
		return false, err
	}
	return true, nil
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
func spellings(p string) []string {
	clean := filepath.Clean(p)
	resolved, ok := resolveDeepest(clean)
	if !ok || resolved == clean {
		return []string{clean}
	}
	return []string{clean, resolved}
}

// resolveDeepest resolves the longest existing prefix of path and re-appends the remainder, so a
// bind source that does not exist yet still compares against the denylist's real spelling.
func resolveDeepest(p string) (string, bool) {
	rest := ""
	for current := p; ; {
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

func underPath(p, prefix string) bool {
	// Clean only leaves a trailing separator on "/", which would make prefix+sep "//" and
	// match nothing -- trim it so every absolute path counts as being under the root.
	prefix = strings.TrimSuffix(prefix, string(filepath.Separator))
	return p == prefix || strings.HasPrefix(p, prefix+string(filepath.Separator))
}
