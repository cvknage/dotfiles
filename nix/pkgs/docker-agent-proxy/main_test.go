package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The denylist is what keeps a sandboxed agent from reading decrypted secrets back out of a
// container, so both containment directions are load-bearing: a source under a denied path,
// and a source that is an ancestor of one.
func TestCheckSource(t *testing.T) {
	base := t.TempDir()

	// The denylist and a bind source can name the same directory through different symlink
	// spellings, so route one side through an alias deliberately -- deriving the mismatch from
	// TMPDIR instead would make this pass or fail depending on how the environment is spelled.
	home := filepath.Join(base, "home")
	alias := filepath.Join(base, "home-alias")
	sshDir := filepath.Join(home, ".ssh")
	project := filepath.Join(home, "code", "project")
	for _, dir := range []string{sshDir, project} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(home, alias); err != nil {
		t.Fatal(err)
	}

	denied := []string{
		filepath.Join(home, ".ssh"),
		filepath.Join(home, ".config", "sops-nix"),
	}
	aliasedDenied := []string{
		filepath.Join(alias, ".ssh"),
		filepath.Join(alias, ".config", "sops-nix"),
	}

	tests := []struct {
		name   string
		source string
		denied []string
		reject bool
	}{
		{"denied path itself", sshDir, denied, true},
		{"under denied path", filepath.Join(sshDir, "id_ed25519"), denied, true},
		{"under denied path, not created yet", filepath.Join(sshDir, "future"), denied, true},
		{"ancestor of denied path", home, denied, true},
		{"filesystem root", string(filepath.Separator), denied, true},
		{"denylist spelled through a symlink", filepath.Join(sshDir, "id_ed25519"), aliasedDenied, true},
		{"ancestor of a symlink-spelled denylist", home, aliasedDenied, true},
		{"source spelled through a symlink", alias, denied, true},
		{"unrelated project path", project, denied, false},
		{"unrelated project path, aliased denylist", project, aliasedDenied, false},
		{"unrelated parent of the project", filepath.Join(home, "code"), denied, false},
		{"nix store", "/nix/store", denied, false},
		{"path traversal into a denied path", home + "/code/../.ssh", denied, true},
		{"double slash into a denied path", home + "//.ssh", denied, true},
		{"trailing slash on a denied path", sshDir + "/", denied, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := checkSource(tt.source, tt.denied) != ""
			if got != tt.reject {
				t.Errorf("checkSource(%q) rejected = %v, want %v", tt.source, got, tt.reject)
			}
		})
	}
}

// checkHostConfig must reject every way a host configuration can reach a denied path: a bind or
// mount whose source is a denied path or an ancestor of one, and the namespace/device escapes
// that expose the host without naming a source at all.
func TestCheckHostConfig(t *testing.T) {
	base := t.TempDir()
	home := filepath.Join(base, "home")
	if err := os.MkdirAll(filepath.Join(home, ".config", "sops-nix"), 0o755); err != nil {
		t.Fatal(err)
	}
	denied := []string{
		filepath.Join(home, ".config", "sops-nix"),
		"/run/docker.sock",
	}
	project := filepath.Join(home, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name   string
		hc     hostConfig
		reject bool
	}{
		{"ancestor bind", hostConfig{Binds: []string{home + ":/host"}}, true},
		{"ancestor bind mount", hostConfig{Mounts: []mount{{Type: "bind", Source: home}}}, true},
		{"local-volume device bind", hostConfig{Mounts: []mount{volumeBindMount(home)}}, true},
		{"docker socket bind", hostConfig{Binds: []string{"/run/docker.sock:/var/run/docker.sock"}}, true},
		{"privileged", hostConfig{Privileged: true}, true},
		{"host pid", hostConfig{PidMode: "host"}, true},
		{"host ipc", hostConfig{IpcMode: "host"}, true},
		{"host userns", hostConfig{UsernsMode: "host"}, true},
		{"cap sys_admin", hostConfig{CapAdd: []string{"SYS_ADMIN"}}, true},
		{"cap prefixed sys_admin", hostConfig{CapAdd: []string{"cap_sys_admin"}}, true},
		{"cap all", hostConfig{CapAdd: []string{"ALL"}}, true},
		{"seccomp unconfined", hostConfig{SecurityOpt: []string{"seccomp=unconfined"}}, true},
		{"apparmor unconfined", hostConfig{SecurityOpt: []string{"apparmor=unconfined"}}, true},
		{"selinux label disable", hostConfig{SecurityOpt: []string{"label=disable"}}, true},
		{"host device", hostConfig{Devices: []struct {
			PathOnHost string `json:"PathOnHost"`
		}{{PathOnHost: "/dev/sda"}}}, true},
		{"ordinary project bind", hostConfig{Binds: []string{project + ":/src"}}, false},
		{"named volume, no device", hostConfig{Mounts: []mount{{Type: "volume", Source: "myvol"}}}, false},
		{"container pid namespace", hostConfig{PidMode: "container:abc"}, false},
		{"benign capabilities", hostConfig{CapAdd: []string{"SYS_PTRACE", "NET_ADMIN"}}, false},
		{"seccomp profile from file", hostConfig{SecurityOpt: []string{"seccomp=/etc/x.json"}}, false},
		{"empty", hostConfig{}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := checkHostConfig(tt.hc, denied) != ""
			if got != tt.reject {
				t.Errorf("checkHostConfig(%+v) rejected = %v, want %v", tt.hc, got, tt.reject)
			}
		})
	}
}

// volumeBindMount builds a Type "volume" mount that is really a local-driver bind to device --
// the inline-volume spelling of a host bind that must be checked like a Type "bind".
func volumeBindMount(device string) mount {
	var m mount
	m.Type = "volume"
	m.VolumeOptions.DriverConfig.Name = "local"
	m.VolumeOptions.DriverConfig.Options = map[string]string{"type": "none", "o": "bind", "device": device}
	return m
}

// fakeDaemon serves inspect JSON for a fixed container id so the guard's re-inspection path can
// be exercised without a real daemon.
func fakeDaemon(t *testing.T, id string, inspect any) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/containers/"+id+"/json" {
			_ = json.NewEncoder(w).Encode(inspect)
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
}

// fakeDaemonRoutes serves inspect JSON for an exact-path route map, so tests spanning multiple
// upstream endpoints (container, volume, exec inspects) can be composed without a real daemon.
func fakeDaemonRoutes(t *testing.T, routes map[string]any) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := routes[r.URL.Path]; ok {
			_ = json.NewEncoder(w).Encode(body)
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
}

func newTestGuard(t *testing.T, denied []string, upstream *httptest.Server) *guard {
	t.Helper()
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	return &guard{
		denied:      denied,
		proxy:       httputil.NewSingleHostReverseProxy(u),
		inspect:     upstream.Client(),
		upstreamURL: upstream.URL,
	}
}

// A container that already binds a denied path must not be startable, exec-able, or reachable
// through the archive endpoint. This is the existing-container surface and also the create-time
// TOCTOU fix -- the source is re-resolved at check time.
func TestGuardActionsRecheckMounts(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	denied := []string{sops}
	inspect := map[string]any{
		"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
	}
	upstream := fakeDaemon(t, "victim", inspect)
	defer upstream.Close()
	g := newTestGuard(t, denied, upstream)

	guarded := []struct {
		method, path string
	}{
		{http.MethodPost, "/containers/victim/start"},
		{http.MethodPost, "/containers/victim/exec"},
		{http.MethodPost, "/containers/victim/attach"},
		{http.MethodGet, "/containers/victim/archive"},
		{http.MethodPut, "/containers/victim/archive"},
	}
	for _, tc := range guarded {
		t.Run(tc.method+" "+tc.path, func(t *testing.T) {
			rec := httptest.NewRecorder()
			g.ServeHTTP(rec, httptest.NewRequest(tc.method, tc.path, nil))
			if rec.Code != http.StatusForbidden {
				t.Errorf("%s %s: status = %d, want 403", tc.method, tc.path, rec.Code)
			}
		})
	}
}

// A container with only an allowed bind passes the action guard.
func TestGuardActionsAllowCleanContainer(t *testing.T) {
	base := t.TempDir()
	project := filepath.Join(base, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	inspect := map[string]any{
		"HostConfig": map[string]any{"Binds": []string{project + ":/src"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": project}},
	}
	upstream := fakeDaemon(t, "clean", inspect)
	defer upstream.Close()
	g := newTestGuard(t, []string{filepath.Join(base, ".ssh")}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/containers/clean/start", nil))
	if rec.Code == http.StatusForbidden {
		t.Errorf("clean container start was rejected: %d", rec.Code)
	}
}

// volumes-from inherits another container's mounts, so a create that references a container
// binding a denied path must be rejected.
func TestCheckContainerCreateVolumesFrom(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	inspect := map[string]any{
		"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
	}
	upstream := fakeDaemon(t, "donor", inspect)
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	body := []byte(`{"HostConfig":{"VolumesFrom":["donor:ro"]}}`)
	reason, _, err := g.checkContainerCreate(body)
	if err != nil {
		t.Fatal(err)
	}
	if reason == "" {
		t.Fatal("volumes-from a container binding a denied path was not rejected")
	}
}

// An inline local-driver volume whose device is a denied path is a bind in disguise and must be
// rejected at create, without any /volumes/create call.
func TestServeCreateRejectsInlineVolumeBind(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("inline volume-bind create reached the upstream daemon")
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	body := `{"HostConfig":{"Mounts":[{"Type":"volume","Target":"/loot","VolumeOptions":{"DriverConfig":{"Name":"local","Options":{"type":"none","o":"bind","device":"` + sops + `"}}}}]}}`
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/containers/create", strings.NewReader(body)))
	if rec.Code != http.StatusForbidden {
		t.Errorf("inline volume-bind status = %d, want 403", rec.Code)
	}
}

// An oversized create body is refused with 413 rather than truncated and forwarded unchecked.
func TestServeCreateRejectsOversizedBody(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("oversized body reached the upstream daemon")
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	big := `{"HostConfig":{"Binds":["/x:/y"]},"pad":"` + strings.Repeat("a", maxCreateBody+16) + `"}`
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/containers/create", strings.NewReader(big)))
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("oversized body status = %d, want 413", rec.Code)
	}
}

// The docker socket is not a denylisted directory, so a bind of it only fails if the socket path
// is on the denylist -- verify the create guard catches it end to end.
func TestServeCreateRejectsSocketBind(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("socket-binding create reached the upstream daemon")
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/run/docker.sock", "/run/docker-agent-proxy.sock"}, upstream)

	body := `{"HostConfig":{"Binds":["/run/docker.sock:/var/run/docker.sock"]}}`
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/v1.43/containers/create", strings.NewReader(body)))
	if rec.Code != http.StatusForbidden {
		t.Errorf("socket bind status = %d, want 403", rec.Code)
	}
}

// The daemon accepts any dotted-numeric API version, not just two components -- a three-component
// version must not bypass the create guard.
func TestServeCreateRejectsDeniedBindWithThreeComponentVersion(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("three-component-version create reached the upstream daemon")
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	body := `{"HostConfig":{"Binds":["/home/u/.ssh:/loot"]}}`
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/v1.44.0/containers/create", strings.NewReader(body)))
	if rec.Code != http.StatusForbidden {
		t.Errorf("three-component-version create status = %d, want 403", rec.Code)
	}
}

// Confirmed live against a real daemon: its router matches "/v{version:[0-9.]+}" -- any nonempty
// run of digits and dots, not just a well-formed MAJOR.MINOR pair -- and routes a malformed version
// through to its own version-range check rather than 404ing it outright. A regex requiring at
// least one dot missed every one of these, forwarding the request unchecked; the daemon happened to
// reject each for being out of its supported range, but that's the daemon's incidental
// configuration, not something this guard controls or should depend on.
func TestServeCreateRejectsDeniedBindWithMalformedVersion(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("malformed-version create reached the upstream daemon: %s", r.URL.Path)
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	body := `{"HostConfig":{"Binds":["/home/u/.ssh:/loot"]}}`
	for _, prefix := range []string{"/v1", "/v9999", "/v.44", "/v1.", "/v1..44"} {
		t.Run(prefix, func(t *testing.T) {
			rec := httptest.NewRecorder()
			g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, prefix+"/containers/create", strings.NewReader(body)))
			if rec.Code != http.StatusForbidden {
				t.Errorf("%s/containers/create status = %d, want 403", prefix, rec.Code)
			}
		})
	}
}

// restart reactivates a stopped container's mounts exactly like start does, so a container binding
// a denied path must not be restartable either -- including through a three-component version.
func TestGuardActionsRecheckMountsOnRestart(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	inspect := map[string]any{
		"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
	}
	upstream := fakeDaemon(t, "victim", inspect)
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	for _, path := range []string{"/containers/victim/restart", "/v1.44.0/containers/victim/restart"} {
		rec := httptest.NewRecorder()
		g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, path, nil))
		if rec.Code != http.StatusForbidden {
			t.Errorf("restart %s: status = %d, want 403", path, rec.Code)
		}
	}
}

// A container that cannot be inspected must not be forwarded: a check that cannot verify fails
// closed.
func TestGuardActionFailsClosedOnInspectError(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/containers/whatever/start", nil))
	if rec.Code == http.StatusOK {
		t.Errorf("unverifiable container start was forwarded: %d", rec.Code)
	}
}

// A missing container passes through so the daemon returns its own 404.
func TestGuardActionPassesThroughMissingContainer(t *testing.T) {
	forwarded := false
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/json") {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		forwarded = true
		w.WriteHeader(http.StatusNotFound)
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/containers/ghost/start", nil))
	if !forwarded {
		t.Error("start of a missing container was not forwarded to the daemon")
	}
}

// A Binds entry naming an existing volume, not a host path, must still be checked if that volume
// was created with a device= override pointing at a denied path -- the same exposure as an inline
// VolumeOptions.device, just one level of indirection further.
func TestCheckContainerCreateNamedVolumeDevice(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/volumes/myvol": map[string]any{"Driver": "local", "Options": map[string]string{"device": sops}},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	reason, _, err := g.checkContainerCreate([]byte(`{"HostConfig":{"Binds":["myvol:/secrets"]}}`))
	if err != nil {
		t.Fatal(err)
	}
	if reason == "" {
		t.Fatal("named volume backed by a denied device was not rejected")
	}
}

// A Mounts entry naming an existing volume by Source, even with its own (harmless-looking) inline
// device override, must still be checked against the volume's actual recorded device. Docker's
// volume store returns a pre-existing volume of the same name and silently ignores the client's
// driver opts, so an inline device on the request can't be trusted to reflect what the daemon will
// actually use.
func TestCheckContainerCreateNamedVolumeIgnoresHarmlessInlineDevice(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/volumes/prevol": map[string]any{"Driver": "local", "Options": map[string]string{"device": sops}},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	body := `{"HostConfig":{"Mounts":[{"Type":"volume","Source":"prevol","Target":"/loot",` +
		`"VolumeOptions":{"DriverConfig":{"Name":"local","Options":{"type":"none","o":"bind","device":"/tmp/harmless"}}}}]}}`
	reason, _, err := g.checkContainerCreate([]byte(body))
	if err != nil {
		t.Fatal(err)
	}
	if reason == "" {
		t.Fatal("named volume with a denied recorded device was not rejected despite a harmless inline override")
	}
}

// A named volume with no device override (plain docker-managed storage) passes -- only a
// local-driver device= binding is a host-path exposure.
func TestCheckContainerCreateNamedVolumeNoDevice(t *testing.T) {
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/volumes/myvol": map[string]any{"Driver": "local", "Options": map[string]string{}},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{"/home/u/.ssh"}, upstream)

	reason, _, err := g.checkContainerCreate([]byte(`{"HostConfig":{"Binds":["myvol:/data"]}}`))
	if err != nil {
		t.Fatal(err)
	}
	if reason != "" {
		t.Errorf("plain named volume was rejected: %q", reason)
	}
}

// checkContainerCreate must rewrite VolumesFrom entries to the referenced container's resolved
// Id before forwarding, the same way serveAction pins actions to a resolved Id -- otherwise a
// rename onto the checked name, between this check and the daemon processing the create, could
// substitute a different container. The rewrite must also leave every other field of the create
// body untouched.
func TestCheckContainerCreateRewritesVolumesFromToResolvedID(t *testing.T) {
	base := t.TempDir()
	project := filepath.Join(base, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/containers/clean/json": map[string]any{
			"Id":         "resolved123",
			"HostConfig": map[string]any{"Binds": []string{project + ":/src"}},
			"Mounts":     []map[string]any{{"Type": "bind", "Source": project}},
		},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{filepath.Join(base, ".ssh")}, upstream)

	reason, forward, err := g.checkContainerCreate([]byte(`{"Image":"alpine","HostConfig":{"VolumesFrom":["clean:ro"]}}`))
	if err != nil {
		t.Fatal(err)
	}
	if reason != "" {
		t.Fatalf("clean volumes-from container was rejected: %q", reason)
	}
	var out map[string]any
	if err := json.Unmarshal(forward, &out); err != nil {
		t.Fatal(err)
	}
	if out["Image"] != "alpine" {
		t.Errorf("rewritten body lost an unrelated field: %v", out)
	}
	hc, _ := out["HostConfig"].(map[string]any)
	vf, _ := hc["VolumesFrom"].([]any)
	if len(vf) != 1 || vf[0] != "resolved123:ro" {
		t.Errorf("VolumesFrom = %v, want [\"resolved123:ro\"]", vf)
	}
}

// serveAction must forward against the container's resolved Id, not the original name -- a rename
// onto the checked name in the gap between the check and the forward could otherwise substitute a
// different container.
func TestServeActionForwardsResolvedID(t *testing.T) {
	base := t.TempDir()
	project := filepath.Join(base, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	var forwardedPath string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/containers/clean/json" {
			_ = json.NewEncoder(w).Encode(map[string]any{
				"Id":         "abc123resolved",
				"HostConfig": map[string]any{"Binds": []string{project + ":/src"}},
				"Mounts":     []map[string]any{{"Type": "bind", "Source": project}},
			})
			return
		}
		forwardedPath = r.URL.Path
		w.WriteHeader(http.StatusNoContent)
	}))
	defer upstream.Close()
	g := newTestGuard(t, []string{filepath.Join(base, ".ssh")}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/v1.44/containers/clean/start", nil))
	if forwardedPath != "/v1.44/containers/abc123resolved/start" {
		t.Errorf("forwarded path = %q, want the id-pinned path", forwardedPath)
	}
}

// A %2F in the id segment decodes to a literal slash in r.URL.Path before actionRe ever sees it --
// the same normalization Go's http server applies to any incoming request, real daemon included --
// so it must not let a denied container's action past the mount re-check.
func TestServeActionRechecksMountsWithEncodedSlash(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	inspect := map[string]any{
		"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
	}
	upstream := fakeDaemon(t, "victim", inspect)
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	req := httptest.NewRequest(http.MethodPost, "/containers%2Fvictim/start", nil)
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Errorf("%%2F-encoded action path: status = %d, want 403 (decoded to %q)", rec.Code, req.URL.Path)
	}
}

// POST /exec/{execId}/start actually runs an already-registered exec, unlike POST
// /containers/{id}/exec which only creates it -- it must get the same mount re-check, resolved
// through the exec's owning container.
func TestServeExecStartRechecksOwningContainer(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/exec/exec1/json": map[string]any{"ContainerID": "victim"},
		"/containers/victim/json": map[string]any{
			"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
			"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
		},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/exec/exec1/start", nil))
	if rec.Code != http.StatusForbidden {
		t.Errorf("exec-start on a denied-mount container: status = %d, want 403", rec.Code)
	}
}

// A clean exec target passes exec-start.
func TestServeExecStartAllowsCleanContainer(t *testing.T) {
	base := t.TempDir()
	project := filepath.Join(base, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/exec/exec1/json": map[string]any{"ContainerID": "clean"},
		"/containers/clean/json": map[string]any{
			"HostConfig": map[string]any{"Binds": []string{project + ":/src"}},
			"Mounts":     []map[string]any{{"Type": "bind", "Source": project}},
		},
	})
	defer upstream.Close()
	g := newTestGuard(t, []string{filepath.Join(base, ".ssh")}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/exec/exec1/start", nil))
	if rec.Code == http.StatusForbidden {
		t.Errorf("clean exec target was rejected: %d", rec.Code)
	}
}

// GET /containers/{id}/attach/ws is the websocket variant of attach and carries the same
// mount-reachable risk; the extra path segment must not defeat the guard.
func TestServeAttachWSRechecksMounts(t *testing.T) {
	base := t.TempDir()
	sops := filepath.Join(base, ".config", "sops-nix")
	if err := os.MkdirAll(sops, 0o755); err != nil {
		t.Fatal(err)
	}
	inspect := map[string]any{
		"Id":         "victim",
		"HostConfig": map[string]any{"Binds": []string{sops + ":/secrets"}},
		"Mounts":     []map[string]any{{"Type": "bind", "Source": sops}},
	}
	upstream := fakeDaemon(t, "victim", inspect)
	defer upstream.Close()
	g := newTestGuard(t, []string{sops}, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/containers/victim/attach/ws", nil))
	if rec.Code != http.StatusForbidden {
		t.Errorf("attach/ws on a denied-mount container: status = %d, want 403", rec.Code)
	}
}

// Swarm mode and service creation/update run in the daemon's own swarm agent, entirely outside
// this guard's per-container checks, and this sandbox never needs Swarm mode -- reject it outright
// rather than trying to enumerate every dangerous shape a service spec can carry.
func TestServeSwarmEndpointsRejected(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("swarm request reached the upstream daemon: %s %s", r.Method, r.URL.Path)
	}))
	defer upstream.Close()
	g := newTestGuard(t, nil, upstream)

	for _, p := range []string{"/swarm/init", "/swarm/join", "/services/create", "/services/abc/update"} {
		t.Run(p, func(t *testing.T) {
			rec := httptest.NewRecorder()
			g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, p, nil))
			if rec.Code != http.StatusForbidden {
				t.Errorf("%s: status = %d, want 403", p, rec.Code)
			}
		})
	}
}

// Plugin installation can declare host mounts, devices, and capabilities of its own -- a
// containerd container started outside this guard's per-container checks -- and this sandbox has
// no legitimate use for it; reject it outright the same way swarm endpoints are rejected.
func TestServePluginEndpointsRejected(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("plugin request reached the upstream daemon: %s %s", r.Method, r.URL.Path)
	}))
	defer upstream.Close()
	g := newTestGuard(t, nil, upstream)

	for _, p := range []string{"/plugins/pull", "/plugins/myplugin/enable"} {
		t.Run(p, func(t *testing.T) {
			rec := httptest.NewRecorder()
			g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, p, nil))
			if rec.Code != http.StatusForbidden {
				t.Errorf("%s: status = %d, want 403", p, rec.Code)
			}
		})
	}
}

// A 200 exec-inspect response naming no owning container is anomalous and must fail closed like
// any other unverifiable target, not pass through to the daemon.
func TestServeExecStartFailsClosedOnMissingContainerID(t *testing.T) {
	upstream := fakeDaemonRoutes(t, map[string]any{
		"/exec/exec1/json": map[string]any{},
	})
	defer upstream.Close()
	g := newTestGuard(t, nil, upstream)

	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/exec/exec1/start", nil))
	if rec.Code != http.StatusBadGateway {
		t.Errorf("exec-start with no ContainerID: status = %d, want 502", rec.Code)
	}
}
