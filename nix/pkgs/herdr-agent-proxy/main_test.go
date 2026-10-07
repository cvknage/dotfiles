package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestCheckCwd(t *testing.T) {
	base := t.TempDir()
	home := filepath.Join(base, "home")
	project := filepath.Join(home, "code", "project")
	secret := filepath.Join(home, ".ssh")
	for _, dir := range []string{project, secret} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	alias := filepath.Join(base, "home-alias")
	if err := os.Symlink(home, alias); err != nil {
		t.Fatal(err)
	}
	// A symlink inside the trusted root pointing outside it: a lexical "is this under the root"
	// check would pass here, since the escape only shows up once the symlink is resolved.
	escape := filepath.Join(project, "escape")
	if err := os.Symlink(secret, escape); err != nil {
		t.Fatal(err)
	}

	roots := []string{project}
	tests := []struct {
		name   string
		cwd    string
		reject bool
	}{
		{"trusted root itself", project, false},
		{"under trusted root", filepath.Join(project, "sub"), false},
		{"not yet created", filepath.Join(project, "future"), false},
		{"ancestor of trusted root", home, true},
		{"unrelated sibling", filepath.Join(home, "code", "other"), true},
		{"root spelled through a symlink", filepath.Join(alias, "code", "project"), false},
		{"symlink inside root escaping it", escape, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			g := newGuard("", roots, "", "")
			got := g.checkCwd(tt.cwd) != ""
			if got != tt.reject {
				t.Errorf("checkCwd(%q) rejected = %v, want %v", tt.cwd, got, tt.reject)
			}
		})
	}
}

func TestParseEnvelopeExactCase(t *testing.T) {
	_, method, _, ok := parseEnvelope([]byte(`{"id":"1","method":"server.stop","Method":"ping"}`))
	if !ok || method != "server.stop" {
		t.Errorf("method = %q, ok=%v, want %q (exact key, not the differently-cased one)", method, ok, "server.stop")
	}
}

func TestFieldString(t *testing.T) {
	params := json.RawMessage(`{"pane_id":"w1:p1","count":3,"label":""}`)
	if v, present, isStr := fieldString(params, "pane_id"); !present || !isStr || v != "w1:p1" {
		t.Errorf("pane_id: %q present=%v isStr=%v", v, present, isStr)
	}
	if _, present, _ := fieldString(params, "missing"); present {
		t.Error("missing field should report absent")
	}
	if _, present, isStr := fieldString(params, "count"); !present || isStr {
		t.Error("count should report present but not a string")
	}
}

func TestCheckPromptText(t *testing.T) {
	if r := checkPromptText("plain text with\ntabs\tand newlines"); r != "" {
		t.Errorf("plain text rejected: %s", r)
	}
	// Bracketed-paste escape: ESC ends the paste early, exposing following bytes as raw keystrokes.
	if r := checkPromptText("hello\x1b[201~\x03\x03cat ~/.ssh/id_ed25519"); r == "" {
		t.Error("text containing ESC should be rejected")
	}
	if r := checkPromptText("ctrl-c: \x03"); r == "" {
		t.Error("text containing a C0 control character should be rejected")
	}
	if r := checkPromptText("del: \x7f"); r == "" {
		t.Error("text containing DEL should be rejected")
	}
}

func TestIsPaneID(t *testing.T) {
	if !isPaneID("w1:p1") {
		t.Error(`"w1:p1" should be recognized as a pane id`)
	}
	if isPaneID("w1") {
		t.Error(`"w1" (a bare workspace id) must not be accepted as a pane id`)
	}
}

func TestBuildRequestDenyByDefault(t *testing.T) {
	g := newGuard("", nil, "claude", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	mustDeny := []string{
		"server.stop", "session.delete", "plugin.install", "terminal.attach",
		"events.subscribe", "worktree.create", "layout.apply", "agent.list",
		"pane.list", "pane.send_text", "pane.send_keys", "pane.close", "pane.read", "tab.create",
	}
	for _, m := range mustDeny {
		if _, _, reason := g.buildRequest(m, json.RawMessage(`{}`)); reason == "" {
			t.Errorf("%q should be denied", m)
		}
	}
}

func TestBuildWorkspaceCreateUsesOwnKindAndStripsEnv(t *testing.T) {
	dir := t.TempDir()
	trusted := filepath.Join(dir, "work")
	os.MkdirAll(trusted, 0o755)
	g := newGuard("", []string{trusted}, "claude", "")

	// A client-supplied "kind"/"env" are both ignored: this proxy always resolves its own
	// configured kind, and never forwards client-chosen env vars into the new pane.
	forward, reason := g.buildWorkspaceCreate(json.RawMessage(fmt.Sprintf(`{"cwd":%q,"kind":"codex","env":{"BASH_ENV":"/tmp/evil.sh"}}`, trusted)))
	if reason != "" {
		t.Fatalf("valid create rejected: %s", reason)
	}
	if _, present := forward["env"]; present {
		t.Error("env must never be forwarded -- the new pane's shell isn't jailed by this proxy, so nothing should inject env into it")
	}
	if _, present := forward["kind"]; present {
		t.Error("kind must never be forwarded upstream as a request field -- it isn't a real herdr param")
	}
}

func TestBuildWorkspaceCreateLabel(t *testing.T) {
	dir := t.TempDir()
	trusted := filepath.Join(dir, "work")
	os.MkdirAll(trusted, 0o755)
	g := newGuard("", []string{trusted}, "claude", "")

	forward, reason := g.buildWorkspaceCreate(json.RawMessage(fmt.Sprintf(`{"cwd":%q,"label":"fix login bug"}`, trusted)))
	if reason != "" {
		t.Fatalf("valid label rejected: %s", reason)
	}
	if forward["label"] != "fix login bug" {
		t.Errorf("label = %v, want it forwarded as given", forward["label"])
	}

	noLabel, reason := g.buildWorkspaceCreate(json.RawMessage(fmt.Sprintf(`{"cwd":%q}`, trusted)))
	if reason != "" {
		t.Fatalf("create without a label should still succeed: %s", reason)
	}
	if _, present := noLabel["label"]; present {
		t.Error("label should be entirely absent from the forwarded request when not supplied, not an empty string")
	}

	if _, reason := g.buildWorkspaceCreate(json.RawMessage(fmt.Sprintf(`{"cwd":%q,"label":"line one\nline two"}`, trusted))); reason == "" {
		t.Error("a label containing a newline should be rejected -- it's a single display line, not free text")
	}

	tooLong := strings.Repeat("x", maxLabelLength+1)
	if _, reason := g.buildWorkspaceCreate(json.RawMessage(fmt.Sprintf(`{"cwd":%q,"label":%q}`, trusted, tooLong))); reason == "" {
		t.Error("an overlong label should be rejected")
	}
}

func TestBuildTabCreateRequiresActiveWorkspace(t *testing.T) {
	dir := t.TempDir()
	trusted := filepath.Join(dir, "work")
	os.MkdirAll(trusted, 0o755)

	noActive := newGuard("", []string{trusted}, "claude", "")
	if _, reason := noActive.buildTabCreate(json.RawMessage(fmt.Sprintf(`{"workspace_id":"w1","cwd":%q}`, trusted))); reason == "" {
		t.Error("tab.create should be rejected when no active workspace is known")
	}

	g := newGuard("", []string{trusted}, "claude", "w1")
	if _, reason := g.buildTabCreate(json.RawMessage(fmt.Sprintf(`{"workspace_id":"w9","cwd":%q}`, trusted))); reason == "" {
		t.Error("tab.create targeting a workspace other than the active one should be rejected")
	}

	forward, reason := g.buildTabCreate(json.RawMessage(fmt.Sprintf(`{"workspace_id":"w1","cwd":%q,"env":{"BASH_ENV":"/tmp/evil.sh"}}`, trusted)))
	if reason != "" {
		t.Fatalf("valid tab.create rejected: %s", reason)
	}
	if forward["workspace_id"] != "w1" {
		t.Errorf("workspace_id = %v, want the active workspace", forward["workspace_id"])
	}
	if _, present := forward["env"]; present {
		t.Errorf("env = %v, want none -- the new pane's shell isn't jailed by this proxy, nothing should forward client-supplied env", forward["env"])
	}
}

func TestBuildPaneSplit(t *testing.T) {
	dir := t.TempDir()
	trusted := filepath.Join(dir, "work")
	os.MkdirAll(trusted, 0o755)
	g := newGuard("", []string{trusted}, "", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	if _, reason := g.buildPaneSplit(json.RawMessage(`{"direction":"right"}`)); reason == "" {
		t.Error("pane.split without target_pane_id should be rejected -- herdr's own ambient-current-pane fallback must never be reachable")
	}
	if _, reason := g.buildPaneSplit(json.RawMessage(`{"target_pane_id":"w9:p9","direction":"right"}`)); reason == "" {
		t.Error("pane.split on an unowned target_pane_id should be rejected")
	}
	if _, reason := g.buildPaneSplit(json.RawMessage(`{"target_pane_id":"w1:p1"}`)); reason == "" {
		t.Error("pane.split without direction should be rejected")
	}
	if _, reason := g.buildPaneSplit(json.RawMessage(`{"target_pane_id":"w1:p1","direction":"up"}`)); reason == "" {
		t.Error(`pane.split with an invalid direction ("up" is not "right"/"down") should be rejected`)
	}

	forward, reason := g.buildPaneSplit(json.RawMessage(fmt.Sprintf(
		`{"target_pane_id":"w1:p1","direction":"right","cwd":%q,"focus":true,"ratio":0.4,"env":{"BASH_ENV":"/tmp/evil.sh"},"right_click":"pane","workspace_id":"w9"}`,
		trusted,
	)))
	if reason != "" {
		t.Fatalf("a valid split should be accepted: %s", reason)
	}
	if forward["target_pane_id"] != "w1:p1" || forward["direction"] != "right" || forward["cwd"] != trusted || forward["focus"] != true || forward["ratio"] != 0.4 {
		t.Errorf("forward = %v, missing or wrong validated fields", forward)
	}
	if _, present := forward["env"]; present {
		t.Error("env must never be forwarded from pane.split, same as workspace.create/tab.create")
	}
	if _, present := forward["right_click"]; present {
		t.Error("right_click must never be forwarded -- not needed for this proxy's use case")
	}
	if _, present := forward["workspace_id"]; present {
		t.Error("workspace_id must never be forwarded -- it's herdr's own alternative split-target selector, which this proxy never lets be reached instead of target_pane_id")
	}

	if _, reason := g.buildPaneSplit(json.RawMessage(`{"target_pane_id":"w1:p1","direction":"right","cwd":"/etc"}`)); reason == "" {
		t.Error("a cwd outside every trusted root should be rejected")
	}
}

func TestBuildTabAndWorkspaceRename(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedTabs["t1"] = struct{}{}
	g.ownedWorkspaces["w1"] = struct{}{}

	if _, reason := g.buildTabRename(json.RawMessage(`{"tab_id":"t9","label":"assignment"}`)); reason == "" {
		t.Error("tab.rename on an unowned tab should be rejected")
	}
	if _, reason := g.buildTabRename(json.RawMessage(`{"tab_id":"t1"}`)); reason == "" {
		t.Error("tab.rename without a label should be rejected")
	}
	if _, reason := g.buildTabRename(json.RawMessage(`{"tab_id":"t1","label":"line one\nline two"}`)); reason == "" {
		t.Error("tab.rename with a control character in the label should be rejected, same as workspace.create/tab.create's label")
	}
	if _, reason := g.buildTabRename(json.RawMessage(fmt.Sprintf(`{"tab_id":"t1","label":%q}`, strings.Repeat("x", maxLabelLength+1)))); reason == "" {
		t.Error("tab.rename with an overlong label should be rejected")
	}
	forward, reason := g.buildTabRename(json.RawMessage(`{"tab_id":"t1","label":"assignment"}`))
	if reason != "" {
		t.Fatalf("a valid tab.rename should be accepted: %s", reason)
	}
	if forward["tab_id"] != "t1" || forward["label"] != "assignment" {
		t.Errorf("forward = %v, want tab_id t1 and label assignment", forward)
	}

	if _, reason := g.buildWorkspaceRename(json.RawMessage(`{"workspace_id":"w9","label":"assignment"}`)); reason == "" {
		t.Error("workspace.rename on an unowned workspace should be rejected")
	}
	forward, reason = g.buildWorkspaceRename(json.RawMessage(`{"workspace_id":"w1","label":"assignment"}`))
	if reason != "" {
		t.Fatalf("a valid workspace.rename should be accepted: %s", reason)
	}
	if forward["workspace_id"] != "w1" || forward["label"] != "assignment" {
		t.Errorf("forward = %v, want workspace_id w1 and label assignment", forward)
	}
}

func TestBuildPaneRename(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	if _, reason := g.buildPaneRename(json.RawMessage(`{"pane_id":"w9:p9","label":"agent-a"}`)); reason == "" {
		t.Error("pane.rename on an unowned pane should be rejected")
	}
	if _, reason := g.buildPaneRename(json.RawMessage(`{"pane_id":"w1:p1"}`)); reason == "" {
		t.Error("pane.rename without a label should be rejected -- this proxy never exposes herdr's own label-clearing behavior")
	}
	if _, reason := g.buildPaneRename(json.RawMessage(`{"pane_id":"w1:p1","label":null}`)); reason == "" {
		t.Error(`pane.rename with a null label should be rejected, same as omitting it -- herdr's own schema allows null here to clear the pane's label, which this proxy must never expose`)
	}
	if _, reason := g.buildPaneRename(json.RawMessage(`{"pane_id":"w1:p1","label":"line one\nline two"}`)); reason == "" {
		t.Error("pane.rename with a control character in the label should be rejected")
	}
	forward, reason := g.buildPaneRename(json.RawMessage(`{"pane_id":"w1:p1","label":"agent-a"}`))
	if reason != "" {
		t.Fatalf("a valid pane.rename should be accepted: %s", reason)
	}
	if forward["pane_id"] != "w1:p1" || forward["label"] != "agent-a" {
		t.Errorf("forward = %v, want pane_id w1:p1 and label agent-a", forward)
	}
}

// TestGrantSplitPaneAppendsToCorrectContainer is the regression test for the ownership-bookkeeping
// side of pane.split: the new pane must join whichever container (tab or workspace) is actually
// tracked as owned, so a later tab.close/workspace.close revokes it along with everything else in that
// container -- and must never be granted at all if neither container is owned.
func TestGrantSplitPaneAppendsToCorrectContainer(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedTabs["t1"] = struct{}{}
	g.tabPanes["t1"] = []string{"w1:p1"}
	g.ownedWorkspaces["w2"] = struct{}{}
	g.workspacePanes["w2"] = []string{"w2:p1"}

	g.grantSplitPane(json.RawMessage(`{"pane":{"pane_id":"w1:p2","tab_id":"t1","workspace_id":"w1"}}`))
	if _, owned := g.ownedPanes["w1:p2"]; !owned {
		t.Error("a pane split into an owned tab should be granted")
	}
	if len(g.tabPanes["t1"]) != 2 {
		t.Errorf("tabPanes[t1] = %v, want both the original and split pane", g.tabPanes["t1"])
	}

	g.grantSplitPane(json.RawMessage(`{"pane":{"pane_id":"w2:p2","tab_id":"t9","workspace_id":"w2"}}`))
	if _, owned := g.ownedPanes["w2:p2"]; !owned {
		t.Error("a pane split into an owned workspace (tab not separately owned) should be granted")
	}
	if len(g.workspacePanes["w2"]) != 2 {
		t.Errorf("workspacePanes[w2] = %v, want both the original and split pane", g.workspacePanes["w2"])
	}

	g.grantSplitPane(json.RawMessage(`{"pane":{"pane_id":"w9:p9","tab_id":"t9","workspace_id":"w9"}}`))
	if _, owned := g.ownedPanes["w9:p9"]; owned {
		t.Error("a pane whose reported tab/workspace are both unowned must never be granted")
	}

	// A malformed or error-shaped response (no "pane" object, or no pane_id) must never grant
	// anything either -- relayUpstreamToClient only calls grantSplitPane for a successful result, but
	// grantSplitPane itself must still fail closed on bad input, not just well-behaved ones.
	g.grantSplitPane(json.RawMessage(`{}`))
	g.grantSplitPane(json.RawMessage(`{"pane":{"tab_id":"t1","workspace_id":"w1"}}`))
	if len(g.tabPanes["t1"]) != 2 {
		t.Errorf("a response with no pane_id must not grant or append anything; tabPanes[t1] = %v", g.tabPanes["t1"])
	}

	g.revokeWorkspace("w2")
	if _, owned := g.ownedPanes["w2:p2"]; owned {
		t.Error("workspace.close must revoke a pane that was split into that workspace, not just its original root pane")
	}
}

func TestBuildAgentStartRequiresOwnKind(t *testing.T) {
	g := newGuard("", nil, "claude", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	if _, _, reason := g.buildRequest("agent.start", json.RawMessage(`{"pane_id":"w1:p1","name":"a","kind":"claude"}`)); reason != "" {
		t.Errorf("matching kind should be allowed, got: %s", reason)
	}
	if _, _, reason := g.buildRequest("agent.start", json.RawMessage(`{"pane_id":"w1:p1","name":"a","kind":"codex"}`)); reason == "" {
		t.Error("a kind other than this sandbox's own configured kind should be rejected")
	}
	if _, _, reason := g.buildRequest("agent.start", json.RawMessage(`{"pane_id":"w9:p9","name":"a","kind":"claude"}`)); reason == "" {
		t.Error("agent.start on an unowned pane should be rejected")
	}
}

// TestOwnedWorkspaceNotAcceptedAsPaneTarget is the regression test for the id-type-confusion
// finding: an owned workspace id must never satisfy a pane/target field, even though both are
// plain strings tracked by this proxy -- herdr resolves an agent target as "agent name or pane
// id", so a bare workspace id slipping through could address an unrelated live agent.
func TestOwnedWorkspaceNotAcceptedAsPaneTarget(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedWorkspaces["w7"] = struct{}{}

	for _, method := range []string{"agent.get", "agent.read", "agent.send_keys", "agent.prompt", "agent.wait"} {
		params := json.RawMessage(`{"target":"w7","keys":["enter"],"text":"hi"}`)
		if _, _, reason := g.buildRequest(method, params); reason == "" {
			t.Errorf("%s: an owned workspace id must not be accepted as target, got no error", method)
		}
	}
}

func TestBuildAgentReadSourceUsesWireSpelling(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	if _, reason := g.buildAgentRead(json.RawMessage(`{"target":"w1:p1","source":"recent_unwrapped"}`), true); reason != "" {
		t.Errorf("the real wire value recent_unwrapped should be accepted, got: %s", reason)
	}
	if _, reason := g.buildAgentRead(json.RawMessage(`{"target":"w1:p1","source":"recent-unwrapped"}`), true); reason == "" {
		t.Error("the CLI-only hyphenated spelling should never reach this proxy and must be rejected")
	}
}

func TestBuildAgentSendKeysAllowlist(t *testing.T) {
	g := newGuard("", nil, "", "")
	g.ownedPanes["w1:p1"] = struct{}{}

	for _, key := range []string{"enter", "up", "down", "esc", "escape", "ENTER"} {
		if _, _, reason := g.buildRequest("agent.send_keys", json.RawMessage(fmt.Sprintf(`{"target":"w1:p1","keys":["%s"]}`, key))); reason != "" {
			t.Errorf("key %q should be permitted, got: %s", key, reason)
		}
	}
	for _, key := range []string{"ctrl+c", "ctrl+d", "tab", "a"} {
		if _, _, reason := g.buildRequest("agent.send_keys", json.RawMessage(fmt.Sprintf(`{"target":"w1:p1","keys":["%s"]}`, key))); reason == "" {
			t.Errorf("key %q must be rejected", key)
		}
	}
}

// TestGuardEndToEnd drives a real guard over real unix sockets against a fake upstream: a
// workspace.create (with the real herdr response shape) grants exactly its own ids and records the
// declared kind; agent.start with the matching kind on that pane is forwarded; a mismatched kind or
// an unowned pane is rejected; a denied method never reaches upstream; workspace.close revokes
// ownership.
func TestGuardEndToEnd(t *testing.T) {
	dir := t.TempDir()
	upstreamPath := filepath.Join(dir, "upstream.sock")
	listenPath := filepath.Join(dir, "proxy.sock")
	trustedRoot := filepath.Join(dir, "work")
	os.MkdirAll(trustedRoot, 0o755)

	upstreamLn, err := net.Listen("unix", upstreamPath)
	if err != nil {
		t.Fatal(err)
	}
	defer upstreamLn.Close()

	reachedUpstream := make(chan string, 8)
	var lastParams json.RawMessage
	go func() {
		conn, err := upstreamLn.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			var req struct {
				ID     json.RawMessage `json:"id"`
				Method string          `json:"method"`
				Params json.RawMessage `json:"params"`
			}
			json.Unmarshal(scanner.Bytes(), &req)
			reachedUpstream <- req.Method
			id := idString(req.ID)
			switch req.Method {
			case "workspace.create":
				lastParams = req.Params
				fmt.Fprintf(conn, `{"id":%q,"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"t1"},"root_pane":{"pane_id":"w1:p1"}}}`+"\n", id)
			default:
				fmt.Fprintf(conn, `{"id":%q,"result":{}}`+"\n", id)
			}
		}
	}()

	g := newGuard(upstreamPath, []string{trustedRoot}, "claude", "")
	proxyLn, err := net.Listen("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer proxyLn.Close()
	go func() {
		for {
			conn, err := proxyLn.Accept()
			if err != nil {
				return
			}
			go g.handleConn(conn)
		}
	}()

	client, err := net.Dial("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	reader := bufio.NewScanner(client)
	reader.Buffer(make([]byte, 0, 64*1024), maxLineLength)
	send := func(line string) string {
		fmt.Fprintln(client, line)
		if !reader.Scan() {
			t.Fatalf("no response to %s: %v", line, reader.Err())
		}
		return reader.Text()
	}
	isError := func(resp string) bool { return strings.Contains(resp, `"error"`) }

	createResp := send(fmt.Sprintf(`{"id":"1","method":"workspace.create","params":{"cwd":%q,"kind":"claude"}}`, trustedRoot))
	if isError(createResp) {
		t.Fatalf("workspace.create rejected: %s", createResp)
	}
	if strings.Contains(string(lastParams), `"env"`) {
		t.Fatalf("upstream received an env field %s, want none -- this proxy never injects or forwards env", lastParams)
	}

	startResp := send(`{"id":"2","method":"agent.start","params":{"pane_id":"w1:p1","name":"a","kind":"claude"}}`)
	if isError(startResp) {
		t.Fatalf("agent.start on the matching kind was rejected: %s", startResp)
	}

	mismatchResp := send(`{"id":"3","method":"agent.wait","params":{"target":"w9:p9"}}`)
	if !isError(mismatchResp) {
		t.Fatalf("agent.wait on an unowned target should be rejected, got: %s", mismatchResp)
	}

	workspaceAsTargetResp := send(`{"id":"3b","method":"agent.wait","params":{"target":"w1"}}`)
	if !isError(workspaceAsTargetResp) {
		t.Fatalf("agent.wait with a bare (non-pane-shaped) owned workspace id as target should be rejected, got: %s", workspaceAsTargetResp)
	}

	deniedResp := send(`{"id":"4","method":"pane.send_text","params":{"pane_id":"w1:p1","text":"cat ~/.ssh/id_ed25519"}}`)
	if !isError(deniedResp) {
		t.Fatalf("pane.send_text must always be rejected, got: %s", deniedResp)
	}

	smuggleResp := send(`{"id":"5","method":"ping","Method":"server.stop","params":{}}`)
	if isError(smuggleResp) {
		t.Fatalf("the exact \"method\" key (ping) should be honored, got: %s", smuggleResp)
	}

	closeResp := send(`{"id":"6","method":"workspace.close","params":{"workspace_id":"w1"}}`)
	if isError(closeResp) {
		t.Fatalf("workspace.close rejected: %s", closeResp)
	}
	staleResp := send(`{"id":"7","method":"agent.read","params":{"target":"w1:p1"}}`)
	if !isError(staleResp) {
		t.Fatalf("agent.read on a pane revoked by workspace.close should be rejected, got: %s", staleResp)
	}

	client.Close()
	var seen []string
	for {
		select {
		case m := <-reachedUpstream:
			seen = append(seen, m)
		default:
			goto done
		}
	}
done:
	for _, forbidden := range []string{"pane.send_text", "server.stop"} {
		for _, m := range seen {
			if m == forbidden {
				t.Fatalf("%q reached upstream; a rejected request must never be forwarded", forbidden)
			}
		}
	}
}

// TestTabCreateEndToEnd exercises tab.create against this sandbox's own pinned active workspace,
// agent.start on the resulting pane, and tab.close -- the alternative to workspace.create that puts
// the spawned agent in a tab next to the caller instead of a separate workspace.
func TestTabCreateEndToEnd(t *testing.T) {
	dir := t.TempDir()
	upstreamPath := filepath.Join(dir, "upstream.sock")
	listenPath := filepath.Join(dir, "proxy.sock")
	trustedRoot := filepath.Join(dir, "work")
	os.MkdirAll(trustedRoot, 0o755)

	upstreamLn, err := net.Listen("unix", upstreamPath)
	if err != nil {
		t.Fatal(err)
	}
	defer upstreamLn.Close()
	go func() {
		conn, err := upstreamLn.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			var req struct {
				ID     json.RawMessage `json:"id"`
				Method string          `json:"method"`
			}
			json.Unmarshal(scanner.Bytes(), &req)
			id := idString(req.ID)
			switch req.Method {
			case "tab.create":
				fmt.Fprintf(conn, `{"id":%q,"result":{"tab":{"tab_id":"t9"},"root_pane":{"pane_id":"w1:p9"}}}`+"\n", id)
			default:
				fmt.Fprintf(conn, `{"id":%q,"result":{}}`+"\n", id)
			}
		}
	}()

	g := newGuard(upstreamPath, []string{trustedRoot}, "claude", "w1")
	proxyLn, err := net.Listen("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer proxyLn.Close()
	go func() {
		for {
			conn, err := proxyLn.Accept()
			if err != nil {
				return
			}
			go g.handleConn(conn)
		}
	}()

	client, err := net.Dial("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	reader := bufio.NewScanner(client)
	reader.Buffer(make([]byte, 0, 64*1024), maxLineLength)
	send := func(line string) string {
		fmt.Fprintln(client, line)
		if !reader.Scan() {
			t.Fatalf("no response to %s: %v", line, reader.Err())
		}
		return reader.Text()
	}
	isError := func(resp string) bool { return strings.Contains(resp, `"error"`) }

	createResp := send(fmt.Sprintf(`{"id":"1","method":"tab.create","params":{"workspace_id":"w1","cwd":%q,"kind":"claude"}}`, trustedRoot))
	if isError(createResp) {
		t.Fatalf("tab.create rejected: %s", createResp)
	}

	startResp := send(`{"id":"2","method":"agent.start","params":{"pane_id":"w1:p9","name":"a","kind":"claude"}}`)
	if isError(startResp) {
		t.Fatalf("agent.start on the tab.create pane was rejected: %s", startResp)
	}

	closeResp := send(`{"id":"3","method":"tab.close","params":{"tab_id":"t9"}}`)
	if isError(closeResp) {
		t.Fatalf("tab.close rejected: %s", closeResp)
	}

	staleResp := send(`{"id":"4","method":"agent.read","params":{"target":"w1:p9"}}`)
	if !isError(staleResp) {
		t.Fatalf("agent.read on a pane revoked by tab.close should be rejected, got: %s", staleResp)
	}

	unrelatedWorkspaceResp := send(`{"id":"5","method":"tab.create","params":{"workspace_id":"w2","cwd":"/tmp","kind":"claude"}}`)
	if !isError(unrelatedWorkspaceResp) {
		t.Fatalf("tab.create targeting a workspace other than the pinned active one should be rejected, got: %s", unrelatedWorkspaceResp)
	}
}

// TestPaneSplitEndToEnd exercises tab.create -> pane.split -> agent.start on both the root and split
// pane -> tab.rename -> tab.close, confirming the split pane is usable like any granted pane and that
// closing the tab revokes BOTH panes (the regression this test exists for: the tabPane -> tabPanes
// refactor must not leave a split pane behind when its tab closes).
func TestPaneSplitEndToEnd(t *testing.T) {
	dir := t.TempDir()
	upstreamPath := filepath.Join(dir, "upstream.sock")
	listenPath := filepath.Join(dir, "proxy.sock")
	trustedRoot := filepath.Join(dir, "work")
	os.MkdirAll(trustedRoot, 0o755)

	upstreamLn, err := net.Listen("unix", upstreamPath)
	if err != nil {
		t.Fatal(err)
	}
	defer upstreamLn.Close()
	go func() {
		conn, err := upstreamLn.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			var req struct {
				ID     json.RawMessage `json:"id"`
				Method string          `json:"method"`
			}
			json.Unmarshal(scanner.Bytes(), &req)
			id := idString(req.ID)
			switch req.Method {
			case "tab.create":
				fmt.Fprintf(conn, `{"id":%q,"result":{"tab":{"tab_id":"t9"},"root_pane":{"pane_id":"w1:p9"}}}`+"\n", id)
			case "pane.split":
				fmt.Fprintf(conn, `{"id":%q,"result":{"type":"pane_info","pane":{"pane_id":"w1:p10","tab_id":"t9","workspace_id":"w1"}}}`+"\n", id)
			default:
				fmt.Fprintf(conn, `{"id":%q,"result":{}}`+"\n", id)
			}
		}
	}()

	g := newGuard(upstreamPath, []string{trustedRoot}, "claude", "w1")
	proxyLn, err := net.Listen("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer proxyLn.Close()
	go func() {
		for {
			conn, err := proxyLn.Accept()
			if err != nil {
				return
			}
			go g.handleConn(conn)
		}
	}()

	client, err := net.Dial("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	reader := bufio.NewScanner(client)
	reader.Buffer(make([]byte, 0, 64*1024), maxLineLength)
	send := func(line string) string {
		fmt.Fprintln(client, line)
		if !reader.Scan() {
			t.Fatalf("no response to %s: %v", line, reader.Err())
		}
		return reader.Text()
	}
	isError := func(resp string) bool { return strings.Contains(resp, `"error"`) }

	createResp := send(fmt.Sprintf(`{"id":"1","method":"tab.create","params":{"workspace_id":"w1","cwd":%q,"kind":"claude"}}`, trustedRoot))
	if isError(createResp) {
		t.Fatalf("tab.create rejected: %s", createResp)
	}

	splitResp := send(`{"id":"2","method":"pane.split","params":{"target_pane_id":"w1:p9","direction":"right"}}`)
	if isError(splitResp) {
		t.Fatalf("pane.split rejected: %s", splitResp)
	}

	for i, paneID := range []string{"w1:p9", "w1:p10"} {
		resp := send(fmt.Sprintf(`{"id":"3.%d","method":"agent.start","params":{"pane_id":%q,"name":"a%d","kind":"claude"}}`, i, paneID, i))
		if isError(resp) {
			t.Fatalf("agent.start on pane %s was rejected: %s", paneID, resp)
		}
	}

	renameResp := send(`{"id":"4","method":"tab.rename","params":{"tab_id":"t9","label":"shared-assignment"}}`)
	if isError(renameResp) {
		t.Fatalf("tab.rename rejected: %s", renameResp)
	}

	closeResp := send(`{"id":"5","method":"tab.close","params":{"tab_id":"t9"}}`)
	if isError(closeResp) {
		t.Fatalf("tab.close rejected: %s", closeResp)
	}

	for _, paneID := range []string{"w1:p9", "w1:p10"} {
		staleResp := send(fmt.Sprintf(`{"id":"6","method":"agent.read","params":{"target":%q}}`, paneID))
		if !isError(staleResp) {
			t.Fatalf("agent.read on pane %s should be rejected after tab.close revoked it, got: %s", paneID, staleResp)
		}
	}
}

// TestHalfCloseDoesNotDropInFlightResponse covers a client that behaves like `echo ... | socat -
// UNIX-CONNECT:...` (the agents/skills/herdr/SKILL.md workspace.create invocation): it writes one
// request and then half-closes (shutdown write), the way EOF on socat's stdin does, well before the
// (deliberately delayed) upstream response arrives. A full Close of the proxy's upstream connection
// at that point -- instead of a half-close -- would tear down relayUpstreamToClient's read and the
// response would never reach the client.
func TestHalfCloseDoesNotDropInFlightResponse(t *testing.T) {
	dir := t.TempDir()
	upstreamPath := filepath.Join(dir, "upstream.sock")
	listenPath := filepath.Join(dir, "proxy.sock")
	trustedRoot := filepath.Join(dir, "work")
	os.MkdirAll(trustedRoot, 0o755)

	upstreamLn, err := net.Listen("unix", upstreamPath)
	if err != nil {
		t.Fatal(err)
	}
	defer upstreamLn.Close()
	go func() {
		conn, err := upstreamLn.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		if scanner.Scan() {
			var req struct {
				ID json.RawMessage `json:"id"`
			}
			json.Unmarshal(scanner.Bytes(), &req)
			time.Sleep(200 * time.Millisecond) // give the client time to half-close first
			fmt.Fprintf(conn, `{"id":%s,"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"t1"},"root_pane":{"pane_id":"w1:p1"}}}`+"\n", string(req.ID))
		}
	}()

	g := newGuard(upstreamPath, []string{trustedRoot}, "claude", "")
	proxyLn, err := net.Listen("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer proxyLn.Close()
	go func() {
		for {
			conn, err := proxyLn.Accept()
			if err != nil {
				return
			}
			go g.handleConn(conn)
		}
	}()

	conn, err := net.Dial("unix", listenPath)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	client := conn.(*net.UnixConn)

	fmt.Fprintf(client, `{"id":"1","method":"workspace.create","params":{"cwd":%q,"kind":"claude"}}`+"\n", trustedRoot)
	if err := client.CloseWrite(); err != nil {
		t.Fatal(err)
	}

	client.SetReadDeadline(time.Now().Add(2 * time.Second))
	reader := bufio.NewScanner(client)
	reader.Buffer(make([]byte, 0, 64*1024), maxLineLength)
	if !reader.Scan() {
		t.Fatalf("expected the delayed workspace.create response to survive the client's half-close, got: %v", reader.Err())
	}
	if resp := reader.Text(); strings.Contains(resp, `"error"`) || !strings.Contains(resp, `"workspace_id":"w1"`) {
		t.Fatalf("expected the real workspace.create result, got: %s", resp)
	}
}
