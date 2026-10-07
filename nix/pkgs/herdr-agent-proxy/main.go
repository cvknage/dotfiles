// herdr-agent-proxy sits between a sandboxed agent and herdr's real control socket. It does not
// jail a spawned pane's shell -- herdr's own agent.start refuses a pane whose foreground process
// isn't a plain shell it recognizes, which an immediately-jailed pane never is (confirmed live: a
// bwrap-wrapped pane's shell permanently reports agent_pane_busy). Instead, this proxy allowlists a
// narrow set of methods, restricts workspace.create/tab.create's cwd to trusted roots, and tracks
// which workspaces/tabs/panes a given sandboxed caller created so it can't touch anyone else's --
// the actual sandboxing of the spawned agent comes entirely from the agent binary itself (`claude`/
// `codex`/`opencode` on PATH) already being the wrapped, bwrap-jailed version, same as any normal
// terminal. This proxy is responsible for making sure nothing a sandboxed caller sends can smuggle a
// different method/field past what was validated.
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"
)

const maxLineLength = 8 << 20

// allowedKeys excludes anything that could interrupt an agent back to its shell (ctrl+c/d/z) or
// type arbitrary text.
var allowedKeys = map[string]bool{"enter": true, "return": true, "up": true, "down": true, "esc": true, "escape": true}

// recent_unwrapped: the wire value is underscored even though the CLI's own --source flag spells
// it with a hyphen (confirmed via `herdr api schema --json`'s ReadSource enum vs `herdr agent read
// --help`) -- the CLI translates one to the other before this proxy ever sees the request.
var validReadSource = map[string]bool{"visible": true, "recent": true, "recent_unwrapped": true, "detection": true}
var validAgentStates = map[string]bool{"idle": true, "working": true, "blocked": true, "unknown": true, "done": true}

// pendingEntry is recorded only for the methods whose response this guard must act on
// (workspace.create/close, tab.create/close, pane.split). extra carries the one piece of
// request-time context each needs to act on its response: the workspace_id/tab_id being closed for
// workspace.close/tab.close (the other three need none -- every pane this guard ever grants is for
// g.ownKind, never recorded per-pane). Connection-local (request ids are client-chosen), unlike
// guard's own state.
type pendingEntry struct {
	method string
	extra  string
}

var trackedMethods = map[string]bool{
	"workspace.create": true, "workspace.close": true, "tab.create": true, "tab.close": true,
	"pane.split": true,
}

var validSplitDirection = map[string]bool{"right": true, "down": true}

type guard struct {
	upstreamPath string
	trustedRoots []string
	ownKind      string // this sandbox's own agent kind; the only kind it may ever start
	// activeWorkspace is this sandbox's own pre-existing herdr workspace (from $HERDR_WORKSPACE_ID
	// at launch time), if any -- the only workspace_id tab.create will ever accept.
	activeWorkspace string

	mu              sync.Mutex
	ownedWorkspaces map[string]struct{}
	ownedPanes      map[string]struct{} // kept separate from ownedWorkspaces: herdr resolves an
	// agent target as "agent name or pane id", so a workspace id accepted in that slot could
	// address an unrelated live agent whose name happens to collide with it.
	ownedTabs      map[string]struct{} // tab ids created by tab.create, closable via tab.close
	workspacePanes map[string][]string // workspace_id -> pane ids granted alongside it
	tabPanes       map[string][]string // tab_id -> pane ids granted alongside it (root pane, plus any
	// pane.split off an existing pane in that tab), so tab.close revokes all of them
}

func newGuard(upstreamPath string, trustedRoots []string, ownKind string, activeWorkspace string) *guard {
	return &guard{
		upstreamPath:    upstreamPath,
		trustedRoots:    trustedRoots,
		ownKind:         ownKind,
		activeWorkspace: activeWorkspace,
		ownedWorkspaces: map[string]struct{}{},
		ownedPanes:      map[string]struct{}{},
		ownedTabs:       map[string]struct{}{},
		workspacePanes:  map[string][]string{},
		tabPanes:        map[string][]string{},
	}
}

func main() {
	var listenPath, upstreamPath, ownKind, activeWorkspace string
	var trustedRoots stringSlice
	flag.StringVar(&listenPath, "listen", "", "unix socket to listen on")
	flag.StringVar(&upstreamPath, "upstream", "", "real herdr control socket to forward to")
	flag.Var(&trustedRoots, "trusted-root", "path a workspace.create cwd may be created under (repeatable)")
	flag.StringVar(&ownKind, "agent-kind", "", "this sandbox's own agent kind (claude/codex/opencode); the only kind it may ever start")
	flag.StringVar(&activeWorkspace, "active-workspace", "", "this sandbox's own pre-existing workspace id, if known; enables tab.create")
	flag.Parse()

	if listenPath == "" || upstreamPath == "" || ownKind == "" {
		log.Fatal("herdr-agent-proxy: -listen, -upstream, and -agent-kind are required")
	}
	if len(trustedRoots) == 0 {
		log.Println("warning: no trusted roots configured, every workspace.create will be rejected")
	}

	// The launcher backgrounds this process and then execs bwrap/sandbox-exec in its own place,
	// which replaces that shell's image and loses any `trap EXIT` it could have set -- so this
	// process has to notice its own parent dying (reparented to init) rather than being told.
	go exitWhenReparented(os.Getppid(), listenPath)

	if err := os.Remove(listenPath); err != nil && !os.IsNotExist(err) {
		log.Fatalf("removing stale socket: %v", err)
	}
	// Umask instead of a separate chmod after Listen: chmod leaves a window where a concurrent
	// process could replace the just-created socket path with a symlink before permissions land.
	oldUmask := syscall.Umask(0o177)
	ln, err := net.Listen("unix", listenPath)
	syscall.Umask(oldUmask)
	if err != nil {
		log.Fatalf("listen %s: %v", listenPath, err)
	}

	g := newGuard(upstreamPath, trustedRoots, ownKind, activeWorkspace)
	log.Printf("herdr-agent-proxy: %s -> %s (%d trusted roots, agent kind %q, active workspace %q)",
		listenPath, upstreamPath, len(trustedRoots), ownKind, activeWorkspace)
	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Fatalf("accept: %v", err)
		}
		go g.handleConn(conn)
	}
}

// handleConn bridges one client connection to its own upstream connection. pending is scoped to
// this connection (request ids are client-chosen); ownedWorkspaces/workspacePanes/paneKind live on
// guard, shared for the proxy's whole lifetime.
func (g *guard) handleConn(client net.Conn) {
	defer client.Close()
	upstream, err := net.Dial("unix", g.upstreamPath)
	if err != nil {
		log.Printf("dial upstream: %v", err)
		return
	}
	defer upstream.Close()

	var mu sync.Mutex
	pending := map[string]pendingEntry{}
	cw := &safeWriter{w: bufio.NewWriter(client)}

	done := make(chan struct{}, 2)
	go func() {
		g.filterClientToUpstream(client, upstream, cw, &mu, pending)
		// Half-close, not Close: a client EOF (e.g. socat's stdin ending right after it writes one
		// request) only means no more requests are coming, not that any in-flight response should be
		// discarded -- a full Close here would race relayUpstreamToClient's read of that response.
		if uc, ok := upstream.(*net.UnixConn); ok {
			uc.CloseWrite()
		} else {
			upstream.Close()
		}
		done <- struct{}{}
	}()
	go func() {
		g.relayUpstreamToClient(upstream, cw, &mu, pending)
		client.Close()
		done <- struct{}{}
	}()
	<-done
	<-done
}

// safeWriter serializes writes from both the relay path and the deny path, which would otherwise
// interleave and corrupt NDJSON framing for a pipelining client.
type safeWriter struct {
	mu sync.Mutex
	w  *bufio.Writer
}

func (sw *safeWriter) writeLine(data []byte) error {
	sw.mu.Lock()
	defer sw.mu.Unlock()
	if _, err := sw.w.Write(data); err != nil {
		return err
	}
	if _, err := sw.w.WriteString("\n"); err != nil {
		return err
	}
	return sw.w.Flush()
}

func (g *guard) filterClientToUpstream(client, upstream net.Conn, cw *safeWriter, mu *sync.Mutex, pending map[string]pendingEntry) {
	scanner := bufio.NewScanner(client)
	scanner.Buffer(make([]byte, 0, 64*1024), maxLineLength)
	writer := bufio.NewWriter(upstream)

	for scanner.Scan() {
		id, method, params, ok := parseEnvelope(scanner.Bytes())
		if !ok {
			g.deny(cw, id, fmt.Sprintf("method %q could not be parsed", method))
			continue
		}

		forward, extra, reason := g.buildRequest(method, params)
		if reason != "" {
			g.deny(cw, id, reason)
			continue
		}

		if trackedMethods[method] {
			if id == "" {
				g.deny(cw, id, fmt.Sprintf("%s: request id must be a non-empty string", method))
				continue
			}
			mu.Lock()
			if _, exists := pending[id]; exists {
				mu.Unlock()
				g.deny(cw, id, fmt.Sprintf("%s: request id %q is already in flight", method, id))
				continue
			}
			pending[id] = pendingEntry{method: method, extra: extra}
			mu.Unlock()
		}

		out, err := json.Marshal(map[string]any{"id": id, "method": method, "params": forward})
		if err != nil {
			g.deny(cw, id, fmt.Sprintf("%s: could not encode request", method))
			continue
		}
		if _, err := writer.Write(out); err != nil {
			return
		}
		if _, err := writer.WriteString("\n"); err != nil {
			return
		}
		if err := writer.Flush(); err != nil {
			return
		}
	}
	if err := scanner.Err(); err != nil {
		log.Printf("client read error: %v", err)
	}
}

func (g *guard) relayUpstreamToClient(upstream net.Conn, cw *safeWriter, mu *sync.Mutex, pending map[string]pendingEntry) {
	scanner := bufio.NewScanner(upstream)
	scanner.Buffer(make([]byte, 0, 64*1024), maxLineLength)

	for scanner.Scan() {
		line := append([]byte(nil), scanner.Bytes()...)

		var resp struct {
			ID     json.RawMessage `json:"id"`
			Result json.RawMessage `json:"result"`
			Error  json.RawMessage `json:"error"`
		}
		// Pending entries are cleared on ANY response carrying their id, not just a successful one:
		// an error response still answers the request, and leaving the entry behind would make its
		// id "already in flight" for the rest of this connection.
		if json.Unmarshal(line, &resp) == nil && (len(resp.Result) > 0 || len(resp.Error) > 0) {
			id := idString(resp.ID)
			mu.Lock()
			entry, ok := pending[id]
			if ok {
				delete(pending, id)
			}
			mu.Unlock()
			if ok && len(resp.Result) > 0 {
				switch entry.method {
				case "workspace.create":
					g.grantWorkspace(resp.Result)
				case "workspace.close":
					g.revokeWorkspace(entry.extra)
				case "tab.create":
					g.grantTab(resp.Result)
				case "tab.close":
					g.revokeTab(entry.extra)
				case "pane.split":
					g.grantSplitPane(resp.Result)
				}
			}
		}

		if err := cw.writeLine(line); err != nil {
			return
		}
	}
	if err := scanner.Err(); err != nil {
		log.Printf("upstream read error: %v", err)
	}
}

func (g *guard) deny(cw *safeWriter, id, message string) {
	log.Printf("blocked: %s", message)
	data, err := json.Marshal(map[string]any{
		"id":    id,
		"error": map[string]string{"code": "forbidden", "message": "herdr-agent-proxy: " + message},
	})
	if err != nil {
		return
	}
	_ = cw.writeLine(data)
}

// parseEnvelope decodes into a map, never a struct: encoding/json matches struct fields
// case-insensitively and lets a later-occurring key win regardless of case, so
// {"method":"ping","Method":"server.stop"} would decode a `Method string` field as "server.stop"
// while a case-sensitive upstream parser reads the exact "method" key as "ping" (or the reverse,
// depending on key order) -- letting a request smuggle a different method than the one checked
// here. Map decoding has no such fallback.
func parseEnvelope(line []byte) (id, method string, params json.RawMessage, ok bool) {
	var top map[string]json.RawMessage
	if json.Unmarshal(line, &top) != nil {
		return "", "", nil, false
	}
	if raw, present := top["id"]; present {
		id = idString(raw)
	}
	methodRaw, present := top["method"]
	if !present {
		return id, "", nil, false
	}
	if json.Unmarshal(methodRaw, &method) != nil {
		return id, "", nil, false
	}
	return id, method, top["params"], true
}

func (g *guard) buildRequest(method string, params json.RawMessage) (forward map[string]any, extra string, reason string) {
	switch method {
	case "ping":
		return map[string]any{}, "", ""
	case "workspace.create":
		forward, reason = g.buildWorkspaceCreate(params)
		return forward, "", reason
	case "workspace.close":
		id, reason := requireOwnedWorkspace(g, params, "workspace_id")
		if reason != "" {
			return nil, "", "workspace.close: " + reason
		}
		return map[string]any{"workspace_id": id}, id, ""
	case "tab.create":
		forward, reason = g.buildTabCreate(params)
		return forward, "", reason
	case "tab.close":
		id, reason := requireOwnedTab(g, params, "tab_id")
		if reason != "" {
			return nil, "", "tab.close: " + reason
		}
		return map[string]any{"tab_id": id}, id, ""
	case "pane.split":
		forward, reason = g.buildPaneSplit(params)
		return forward, "", reason
	case "tab.rename":
		forward, reason = g.buildTabRename(params)
		return forward, "", reason
	case "workspace.rename":
		forward, reason = g.buildWorkspaceRename(params)
		return forward, "", reason
	case "pane.rename":
		forward, reason = g.buildPaneRename(params)
		return forward, "", reason
	case "agent.start":
		forward, reason = g.buildAgentStart(params)
		return forward, "", reason
	case "agent.get":
		forward, reason = g.buildAgentRead(params, false)
		return forward, "", reason
	case "agent.read":
		forward, reason = g.buildAgentRead(params, true)
		return forward, "", reason
	case "agent.send_keys":
		forward, reason = g.buildAgentSendKeys(params)
		return forward, "", reason
	case "agent.prompt":
		forward, reason = g.buildAgentPrompt(params)
		return forward, "", reason
	case "agent.wait":
		forward, reason = g.buildAgentWait(params)
		return forward, "", reason
	default:
		return nil, "", fmt.Sprintf("method %q is not permitted in the agent sandbox", method)
	}
}

// buildWorkspaceCreate is the only place a workspace gets created, besides buildTabCreate's tab
// equivalent. Any client-supplied env is dropped: the new pane's shell isn't jailed by this proxy
// (see the package comment), but nothing here lets a sandboxed caller inject env vars -- BASH_ENV,
// LD_PRELOAD, PATH overrides -- into a pane that will, shortly, run an already-sandboxed agent
// binary typed into it.
func (g *guard) buildWorkspaceCreate(params json.RawMessage) (forward map[string]any, reason string) {
	cwd, present, isStr := fieldString(params, "cwd")
	if !present {
		return nil, `workspace.create: missing required "cwd"`
	}
	if !isStr {
		return nil, `workspace.create: "cwd" must be a string`
	}
	if reason := g.checkCwd(cwd); reason != "" {
		return nil, "workspace.create: " + reason
	}
	out := map[string]any{"cwd": cwd}
	label, present, reason := optionalLabel(params)
	if reason != "" {
		return nil, "workspace.create: " + reason
	}
	if present {
		out["label"] = label
	}
	return out, ""
}

// optionalLabel reads and validates a client-supplied "label" for workspace.create/tab.create, so a
// sandboxed caller can give its own spawned pane a name describing the task instead of a bare number.
// tab.rename/workspace.rename/pane.rename reuse it too, via requireLabel below, where the label is the
// method's whole point rather than one optional field among several.
func optionalLabel(params json.RawMessage) (label string, present bool, reason string) {
	label, present, isStr := fieldString(params, "label")
	if !present {
		return "", false, ""
	}
	if !isStr {
		return "", false, `"label" must be a string`
	}
	if reason := checkLabel(label); reason != "" {
		return "", false, reason
	}
	return label, true, ""
}

// buildTabCreate is workspace.create's sibling for adding a pane to this sandbox's own pre-existing
// workspace instead of a fresh one, so a spawned agent shows up as a tab next to the caller instead
// of in a hidden workspace. workspace_id is never caller-chosen: it must equal activeWorkspace,
// pinned from $HERDR_WORKSPACE_ID at proxy start, not read from the request.
func (g *guard) buildTabCreate(params json.RawMessage) (forward map[string]any, reason string) {
	if g.activeWorkspace == "" {
		return nil, "tab.create: no active workspace known for this sandbox"
	}
	workspaceID, present, isStr := fieldString(params, "workspace_id")
	if !present {
		return nil, `tab.create: missing required "workspace_id"`
	}
	if !isStr {
		return nil, `tab.create: "workspace_id" must be a string`
	}
	if workspaceID != g.activeWorkspace {
		return nil, "tab.create: workspace_id must be this sandbox's own active workspace"
	}
	cwd, present, isStr := fieldString(params, "cwd")
	if !present {
		return nil, `tab.create: missing required "cwd"`
	}
	if !isStr {
		return nil, `tab.create: "cwd" must be a string`
	}
	if reason := g.checkCwd(cwd); reason != "" {
		return nil, "tab.create: " + reason
	}
	out := map[string]any{"workspace_id": workspaceID, "cwd": cwd}
	label, present, reason := optionalLabel(params)
	if reason != "" {
		return nil, "tab.create: " + reason
	}
	if present {
		out["label"] = label
	}
	return out, ""
}

// buildPaneSplit adds a second (or further) pane to a tab/workspace this guard already granted --
// e.g. to put several agents working on the same assignment in one tab instead of separate tabs.
// "target_pane_id" is required even though herdr's own schema allows omitting it (falling back to
// herdr's own ambient "current pane"): that ambient pane could be anyone's, not this sandbox's own,
// same reasoning as tab.create pinning workspace_id instead of trusting an implicit default. "env",
// "right_click", and "workspace_id" are deliberately never read or forwarded: env for the same reason
// workspace.create/tab.create never forward it (the new pane's shell isn't jailed by this proxy);
// right_click has no use case here; workspace_id is herdr's own alternative way to pick a split target
// when target_pane_id is omitted, which this proxy never allows to be reached in the first place.
func (g *guard) buildPaneSplit(params json.RawMessage) (map[string]any, string) {
	targetPaneID, reason := requireOwnedPane(g, params, "target_pane_id")
	if reason != "" {
		return nil, "pane.split: " + reason
	}
	direction, present, isStr := fieldString(params, "direction")
	if !present {
		return nil, `pane.split: missing required "direction"`
	}
	if !isStr || !validSplitDirection[direction] {
		return nil, `pane.split: "direction" must be "right" or "down"`
	}
	out := map[string]any{"target_pane_id": targetPaneID, "direction": direction}
	if cwd, present, isStr := fieldString(params, "cwd"); present {
		if !isStr {
			return nil, `pane.split: "cwd" must be a string`
		}
		if reason := g.checkCwd(cwd); reason != "" {
			return nil, "pane.split: " + reason
		}
		out["cwd"] = cwd
	}
	if raw, present := rawField(params, "focus"); present {
		var focus bool
		if json.Unmarshal(raw, &focus) != nil {
			return nil, `pane.split: "focus" must be a boolean`
		}
		out["focus"] = focus
	}
	if raw, present := rawField(params, "ratio"); present {
		var ratio float64
		if json.Unmarshal(raw, &ratio) != nil {
			return nil, `pane.split: "ratio" must be a number`
		}
		out["ratio"] = ratio
	}
	return out, ""
}

// requireLabel is optionalLabel plus the missing-label case, for tab.rename/workspace.rename/
// pane.rename, where (unlike workspace.create/tab.create) the label isn't optional -- it's the
// method's whole point.
func requireLabel(method string, params json.RawMessage) (string, string) {
	label, present, reason := optionalLabel(params)
	if reason != "" {
		return "", method + ": " + reason
	}
	if !present {
		return "", fmt.Sprintf(`%s: missing required "label"`, method)
	}
	return label, ""
}

// buildTabRename and buildWorkspaceRename let a sandboxed caller relabel a tab/workspace it already
// owns -- e.g. to rename an assignment, independent of any individual pane/agent's own name (set via
// buildPaneRename below, not this).
func (g *guard) buildTabRename(params json.RawMessage) (map[string]any, string) {
	tabID, reason := requireOwnedTab(g, params, "tab_id")
	if reason != "" {
		return nil, "tab.rename: " + reason
	}
	label, reason := requireLabel("tab.rename", params)
	if reason != "" {
		return nil, reason
	}
	return map[string]any{"tab_id": tabID, "label": label}, ""
}

func (g *guard) buildWorkspaceRename(params json.RawMessage) (map[string]any, string) {
	workspaceID, reason := requireOwnedWorkspace(g, params, "workspace_id")
	if reason != "" {
		return nil, "workspace.rename: " + reason
	}
	label, reason := requireLabel("workspace.rename", params)
	if reason != "" {
		return nil, reason
	}
	return map[string]any{"workspace_id": workspaceID, "label": label}, ""
}

// buildPaneRename labels an individual pane this guard already owns, independent of its tab/
// workspace's own label -- so each agent sharing a tab (via pane.split) can be told apart by name,
// while the tab/workspace keeps a separate, stable label for the shared assignment. Unlike
// tab.rename/workspace.rename, herdr's own schema allows an absent/null label here (clearing it); this
// proxy still requires one, since this method's only use in this skill is setting a pane's agent name.
func (g *guard) buildPaneRename(params json.RawMessage) (map[string]any, string) {
	paneID, reason := requireOwnedPane(g, params, "pane_id")
	if reason != "" {
		return nil, "pane.rename: " + reason
	}
	label, reason := requireLabel("pane.rename", params)
	if reason != "" {
		return nil, reason
	}
	return map[string]any{"pane_id": paneID, "label": label}, ""
}

func (g *guard) buildAgentStart(params json.RawMessage) (map[string]any, string) {
	paneID, reason := requireOwnedPane(g, params, "pane_id")
	if reason != "" {
		return nil, "agent.start: " + reason
	}
	name, present, isStr := fieldString(params, "name")
	if !present {
		return nil, `agent.start: missing required "name"`
	}
	if !isStr {
		return nil, `agent.start: "name" must be a string`
	}
	kind, present, isStr := fieldString(params, "kind")
	if !present {
		return nil, `agent.start: missing required "kind"`
	}
	if !isStr {
		return nil, `agent.start: "kind" must be a string`
	}
	if kind != g.ownKind {
		return nil, fmt.Sprintf("agent.start: this sandbox may only start kind %q, not %q", g.ownKind, kind)
	}
	out := map[string]any{"pane_id": paneID, "name": name, "kind": kind}
	if raw, present := rawField(params, "args"); present {
		var args []string
		if json.Unmarshal(raw, &args) != nil {
			return nil, `agent.start: "args" must be an array of strings`
		}
		out["args"] = args
	}
	if raw, present := rawField(params, "timeout_ms"); present {
		var tm float64
		if json.Unmarshal(raw, &tm) != nil {
			return nil, `agent.start: "timeout_ms" must be a number`
		}
		out["timeout_ms"] = tm
	}
	return out, ""
}

func (g *guard) buildAgentRead(params json.RawMessage, allowExtras bool) (map[string]any, string) {
	target, reason := requireOwnedPane(g, params, "target")
	if reason != "" {
		return nil, reason
	}
	out := map[string]any{"target": target}
	if !allowExtras {
		return out, ""
	}
	if raw, present := rawField(params, "source"); present {
		var src string
		if json.Unmarshal(raw, &src) != nil || !validReadSource[src] {
			return nil, `agent.read: invalid "source"`
		}
		out["source"] = src
	}
	if raw, present := rawField(params, "lines"); present {
		var n float64
		if json.Unmarshal(raw, &n) != nil {
			return nil, `agent.read: "lines" must be a number`
		}
		out["lines"] = n
	}
	if raw, present := rawField(params, "format"); present {
		var format string
		if json.Unmarshal(raw, &format) != nil || (format != "text" && format != "ansi") {
			return nil, `agent.read: invalid "format"`
		}
		out["format"] = format
	}
	if raw, present := rawField(params, "strip_ansi"); present {
		var stripAnsi bool
		if json.Unmarshal(raw, &stripAnsi) != nil {
			return nil, `agent.read: "strip_ansi" must be a boolean`
		}
		out["strip_ansi"] = stripAnsi
	}
	return out, ""
}

func (g *guard) buildAgentSendKeys(params json.RawMessage) (map[string]any, string) {
	target, reason := requireOwnedPane(g, params, "target")
	if reason != "" {
		return nil, "agent.send_keys: " + reason
	}
	raw, present := rawField(params, "keys")
	if !present {
		return nil, `agent.send_keys: missing required "keys"`
	}
	var keys []string
	if json.Unmarshal(raw, &keys) != nil {
		var one string
		if json.Unmarshal(raw, &one) != nil {
			return nil, `agent.send_keys: "keys" must be a string or array of strings`
		}
		keys = []string{one}
	}
	if len(keys) == 0 {
		return nil, `agent.send_keys: "keys" must not be empty`
	}
	for _, k := range keys {
		if !allowedKeys[strings.ToLower(k)] {
			return nil, fmt.Sprintf("agent.send_keys: key %q is not permitted (only enter/up/down/esc)", k)
		}
	}
	return map[string]any{"target": target, "keys": keys}, ""
}

func (g *guard) buildAgentPrompt(params json.RawMessage) (map[string]any, string) {
	target, reason := requireOwnedPane(g, params, "target")
	if reason != "" {
		return nil, "agent.prompt: " + reason
	}
	text, present, isStr := fieldString(params, "text")
	if !present {
		return nil, `agent.prompt: missing required "text"`
	}
	if !isStr {
		return nil, `agent.prompt: "text" must be a string`
	}
	if reason := checkPromptText(text); reason != "" {
		return nil, "agent.prompt: " + reason
	}
	out := map[string]any{"target": target, "text": text}
	if raw, present := rawField(params, "wait"); present {
		wait, reason := buildWait(raw)
		if reason != "" {
			return nil, "agent.prompt: " + reason
		}
		out["wait"] = wait
	}
	return out, ""
}

func (g *guard) buildAgentWait(params json.RawMessage) (map[string]any, string) {
	target, reason := requireOwnedPane(g, params, "target")
	if reason != "" {
		return nil, "agent.wait: " + reason
	}
	out := map[string]any{"target": target}
	if raw, present := rawField(params, "until"); present {
		until, reason := validateUntil(raw)
		if reason != "" {
			return nil, "agent.wait: " + reason
		}
		out["until"] = until
	}
	if raw, present := rawField(params, "timeout_ms"); present {
		var tm float64
		if json.Unmarshal(raw, &tm) != nil {
			return nil, `agent.wait: "timeout_ms" must be a number`
		}
		out["timeout_ms"] = tm
	}
	return out, ""
}

func buildWait(raw json.RawMessage) (map[string]any, string) {
	var m map[string]json.RawMessage
	if json.Unmarshal(raw, &m) != nil {
		return nil, `"wait" must be an object`
	}
	out := map[string]any{}
	if untilRaw, present := m["until"]; present {
		until, reason := validateUntil(untilRaw)
		if reason != "" {
			return nil, reason
		}
		out["until"] = until
	}
	if tmRaw, present := m["timeout_ms"]; present {
		var tm float64
		if json.Unmarshal(tmRaw, &tm) != nil {
			return nil, `"timeout_ms" must be a number`
		}
		out["timeout_ms"] = tm
	}
	return out, ""
}

func validateUntil(raw json.RawMessage) ([]string, string) {
	var list []string
	if json.Unmarshal(raw, &list) != nil {
		var one string
		if json.Unmarshal(raw, &one) != nil {
			return nil, `"until" must be a string or array of strings`
		}
		list = []string{one}
	}
	for _, s := range list {
		if !validAgentStates[s] {
			return nil, fmt.Sprintf("unsupported state %q in \"until\"", s)
		}
	}
	return list, ""
}

// checkPromptText rejects control bytes other than \n/\t: herdr submits prompt text via
// bracketed-paste followed by Enter, so an embedded ESC (e.g. ESC[201~) can end the paste early and
// expose any following bytes as raw keystrokes to whatever's at the prompt -- the same shell access
// pane.send_text/send_keys were dropped to prevent.
func checkPromptText(text string) string {
	for _, r := range text {
		if r == '\n' || r == '\t' {
			continue
		}
		if r < 0x20 || r == 0x7f || (r >= 0x80 && r <= 0x9f) {
			return fmt.Sprintf("\"text\" contains a disallowed control character (U+%04X)", r)
		}
	}
	return ""
}

const maxLabelLength = 100

// checkLabel is stricter than checkPromptText: a tab/workspace label is a single display line
// rendered directly in herdr's tab bar, so unlike a prompt it never gets a \n/\t exception, must be
// non-empty, is length-capped by rune (not byte) count to match what SKILL.md tells callers, and
// also rejects line/paragraph separators and bidi control characters -- none are caught by the
// plain C0/C1 check, and either could make a label visually impersonate a different tab's.
func checkLabel(label string) string {
	if label == "" {
		return `"label" must not be empty`
	}
	if n := utf8.RuneCountInString(label); n > maxLabelLength {
		return fmt.Sprintf("\"label\" is too long (%d characters, max %d)", n, maxLabelLength)
	}
	for _, r := range label {
		if r < 0x20 || r == 0x7f || (r >= 0x80 && r <= 0x9f) {
			return fmt.Sprintf("\"label\" contains a disallowed control character (U+%04X)", r)
		}
		if unicode.Is(unicode.Cf, r) || unicode.Is(unicode.Zl, r) || unicode.Is(unicode.Zp, r) {
			return fmt.Sprintf("\"label\" contains a disallowed formatting/separator character (U+%04X)", r)
		}
	}
	return ""
}

// isPaneID reports whether s looks like a herdr pane id ("w1:p1"), not a bare workspace id ("w1").
// Checked in addition to set membership below so a workspace id can never satisfy a pane/target
// field even if ownership bookkeeping elsewhere ever conflated the two.
func isPaneID(s string) bool {
	return strings.Contains(s, ":")
}

func requireOwnedPane(g *guard, params json.RawMessage, field string) (string, string) {
	val, present, isStr := fieldString(params, field)
	if !present {
		return "", fmt.Sprintf("missing required %q", field)
	}
	if !isStr {
		return "", fmt.Sprintf("%q must be a string", field)
	}
	if !isPaneID(val) {
		return "", fmt.Sprintf("%q (%s) is not a pane id", val, field)
	}
	g.mu.Lock()
	_, ok := g.ownedPanes[val]
	g.mu.Unlock()
	if !ok {
		return "", fmt.Sprintf("%q (%s) was not created by this sandbox session", val, field)
	}
	return val, ""
}

func requireOwnedWorkspace(g *guard, params json.RawMessage, field string) (string, string) {
	val, present, isStr := fieldString(params, field)
	if !present {
		return "", fmt.Sprintf("missing required %q", field)
	}
	if !isStr {
		return "", fmt.Sprintf("%q must be a string", field)
	}
	g.mu.Lock()
	_, ok := g.ownedWorkspaces[val]
	g.mu.Unlock()
	if !ok {
		return "", fmt.Sprintf("%q (%s) was not created by this sandbox session", val, field)
	}
	return val, ""
}

// grantWorkspace is called only on a successful workspace.create response. Its tab_id is
// deliberately not tracked: workspace tear-down always goes through workspace.close, never
// tab.close, which is for tabs from tab.create only.
func (g *guard) grantWorkspace(result json.RawMessage) {
	var r struct {
		Workspace struct {
			WorkspaceID string `json:"workspace_id"`
		} `json:"workspace"`
		RootPane struct {
			PaneID string `json:"pane_id"`
		} `json:"root_pane"`
	}
	if json.Unmarshal(result, &r) != nil || r.Workspace.WorkspaceID == "" {
		return
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	g.ownedWorkspaces[r.Workspace.WorkspaceID] = struct{}{}
	if r.RootPane.PaneID != "" {
		g.ownedPanes[r.RootPane.PaneID] = struct{}{}
		g.workspacePanes[r.Workspace.WorkspaceID] = []string{r.RootPane.PaneID}
	}
}

func (g *guard) revokeWorkspace(workspaceID string) {
	if workspaceID == "" {
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	delete(g.ownedWorkspaces, workspaceID)
	for _, id := range g.workspacePanes[workspaceID] {
		delete(g.ownedPanes, id)
	}
	delete(g.workspacePanes, workspaceID)
}

func requireOwnedTab(g *guard, params json.RawMessage, field string) (string, string) {
	val, present, isStr := fieldString(params, field)
	if !present {
		return "", fmt.Sprintf("missing required %q", field)
	}
	if !isStr {
		return "", fmt.Sprintf("%q must be a string", field)
	}
	g.mu.Lock()
	_, ok := g.ownedTabs[val]
	g.mu.Unlock()
	if !ok {
		return "", fmt.Sprintf("%q (%s) was not created by this sandbox session", val, field)
	}
	return val, ""
}

// grantTab is called only on a successful tab.create response. Its shape (tab/root_pane, same
// naming as workspace.create) is confirmed via `herdr api schema --json`'s tab_created variant.
func (g *guard) grantTab(result json.RawMessage) {
	var r struct {
		Tab struct {
			TabID string `json:"tab_id"`
		} `json:"tab"`
		RootPane struct {
			PaneID string `json:"pane_id"`
		} `json:"root_pane"`
	}
	if json.Unmarshal(result, &r) != nil || r.Tab.TabID == "" || r.RootPane.PaneID == "" {
		return
	}
	paneID := r.RootPane.PaneID

	g.mu.Lock()
	defer g.mu.Unlock()
	g.ownedTabs[r.Tab.TabID] = struct{}{}
	g.ownedPanes[paneID] = struct{}{}
	g.tabPanes[r.Tab.TabID] = []string{paneID}
}

func (g *guard) revokeTab(tabID string) {
	if tabID == "" {
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	delete(g.ownedTabs, tabID)
	for _, paneID := range g.tabPanes[tabID] {
		delete(g.ownedPanes, paneID)
	}
	delete(g.tabPanes, tabID)
}

// grantSplitPane is called only on a successful pane.split response. The new pane always belongs to
// the same tab/workspace as the target pane it was split from (already verified owned in
// buildPaneSplit), so it's granted by appending to whichever of tabPanes/workspacePanes that
// container is tracked under -- tab.close/workspace.close then revoke it along with everything else
// in that container. If the response names neither an owned tab nor an owned workspace, nothing is
// granted; this shouldn't happen given the target_pane_id check, but a pane this guard can't attach
// to a container it already owns must never become independently ownable.
func (g *guard) grantSplitPane(result json.RawMessage) {
	var r struct {
		Pane struct {
			PaneID      string `json:"pane_id"`
			TabID       string `json:"tab_id"`
			WorkspaceID string `json:"workspace_id"`
		} `json:"pane"`
	}
	if json.Unmarshal(result, &r) != nil || r.Pane.PaneID == "" {
		return
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	if _, ok := g.ownedTabs[r.Pane.TabID]; ok {
		g.ownedPanes[r.Pane.PaneID] = struct{}{}
		g.tabPanes[r.Pane.TabID] = append(g.tabPanes[r.Pane.TabID], r.Pane.PaneID)
		return
	}
	if _, ok := g.ownedWorkspaces[r.Pane.WorkspaceID]; ok {
		g.ownedPanes[r.Pane.PaneID] = struct{}{}
		g.workspacePanes[r.Pane.WorkspaceID] = append(g.workspacePanes[r.Pane.WorkspaceID], r.Pane.PaneID)
	}
}

// checkCwd uses only the symlink-resolved comparison: a lexical prefix check would pass for a path
// that is lexically under a trusted root but, via a symlink the agent itself created inside that
// root, resolves outside it.
func (g *guard) checkCwd(cwd string) string {
	resolved := resolveDeepest(cwd)
	for _, root := range g.trustedRoots {
		if underPath(resolved, resolveDeepest(root)) {
			return ""
		}
	}
	return fmt.Sprintf("cwd %q is outside every trusted root", cwd)
}

func resolveDeepest(p string) string {
	clean := filepath.Clean(p)
	rest := ""
	for current := clean; ; {
		if real, err := filepath.EvalSymlinks(current); err == nil {
			return filepath.Join(real, rest)
		}
		parent := filepath.Dir(current)
		if parent == current {
			return clean
		}
		rest = filepath.Join(filepath.Base(current), rest)
		current = parent
	}
}

func underPath(p, prefix string) bool {
	p = filepath.Clean(p)
	prefix = strings.TrimSuffix(filepath.Clean(prefix), string(filepath.Separator))
	return p == prefix || strings.HasPrefix(p, prefix+string(filepath.Separator))
}

func idString(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s
	}
	return ""
}

func rawField(params json.RawMessage, field string) (json.RawMessage, bool) {
	if len(params) == 0 {
		return nil, false
	}
	var m map[string]json.RawMessage
	if json.Unmarshal(params, &m) != nil {
		return nil, false
	}
	raw, ok := m[field]
	return raw, ok
}

// fieldString reports presence and string-typedness separately: a field present but not a string
// must be rejected, not treated as absent.
func fieldString(params json.RawMessage, field string) (value string, present, isString bool) {
	raw, ok := rawField(params, field)
	if !ok {
		return "", false, false
	}
	isString = json.Unmarshal(raw, &value) == nil
	return value, true, isString
}

func exitWhenReparented(originalPPID int, listenPath string) {
	for range time.Tick(2 * time.Second) {
		if os.Getppid() != originalPPID {
			os.Remove(listenPath)
			os.Exit(0)
		}
	}
}

type stringSlice []string

func (s *stringSlice) String() string { return strings.Join(*s, ",") }

func (s *stringSlice) Set(v string) error {
	*s = append(*s, v)
	return nil
}
