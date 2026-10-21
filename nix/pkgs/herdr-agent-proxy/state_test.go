package main

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
)

// fakeHerdr answers the three list methods from fixed fixtures.
func fakeHerdr(t *testing.T, panes, tabs, workspaces string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "h.sock")
	ln, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				defer conn.Close()
				line, _ := bufio.NewReader(conn).ReadBytes('\n')
				_, method, _, _ := parseEnvelope(line)
				result := map[string]string{
					"pane.list": panes, "tab.list": tabs, "workspace.list": workspaces,
				}[method]
				conn.Write([]byte(`{"id":"restore","result":` + result + "}\n"))
			}()
		}
	}()
	return path
}

func TestStatePersistsAndRestoresOnlyMatchingGrants(t *testing.T) {
	statePath := filepath.Join(t.TempDir(), "state.json")

	first := newGuard("", nil, "claude", "")
	first.statePath = statePath
	first.grantWorkspace(json.RawMessage(`{"workspace":{"workspace_id":"w1"},"root_pane":{"pane_id":"w1:p1","cwd":"/work/a"}}`), "")
	first.grantWorkspace(json.RawMessage(`{"workspace":{"workspace_id":"w2"},"root_pane":{"pane_id":"w2:p1","cwd":"/work/b"}}`), "")
	first.grantTab(json.RawMessage(`{"tab":{"tab_id":"t1"},"root_pane":{"pane_id":"w3:p1"}}`), "/work/c")
	first.grantSplitPane(json.RawMessage(`{"pane":{"pane_id":"w3:p2","tab_id":"t1","workspace_id":"w3"}}`), "/work/c")
	first.revokeWorkspace("w2")

	// w1's id was reassigned to a pane in another cwd; the tab and its panes are intact.
	upstream := fakeHerdr(t,
		`{"panes":[{"pane_id":"w1:p1","cwd":"/elsewhere"},{"pane_id":"w3:p1","cwd":"/work/c"},{"pane_id":"w3:p2","cwd":"/work/c"}]}`,
		`{"tabs":[{"tab_id":"t1"}]}`,
		`{"workspaces":[{"workspace_id":"w1"}]}`,
	)
	second := newGuard(upstream, nil, "claude", "")
	second.statePath = statePath
	second.restoreState()

	if _, owned := second.ownedWorkspaces["w1"]; owned {
		t.Error("w1's pane now has a different cwd; it must not be restored")
	}
	if _, owned := second.ownedWorkspaces["w2"]; owned {
		t.Error("a closed workspace must not be restored")
	}
	if _, owned := second.ownedTabs["t1"]; !owned {
		t.Fatal("t1 and its panes still match; it should be restored")
	}
	for _, pane := range []string{"w3:p1", "w3:p2"} {
		if _, owned := second.ownedPanes[pane]; !owned {
			t.Errorf("pane %s should be restored with its tab", pane)
		}
	}
	if st := readState(statePath); len(st.Workspaces) != 0 || len(st.Tabs) != 1 {
		t.Errorf("stale entries should be pruned from disk, got %+v", st)
	}
}

func TestRestoreStateKeepsFileWhenHerdrUnreachable(t *testing.T) {
	statePath := filepath.Join(t.TempDir(), "state.json")
	first := newGuard("", nil, "claude", "")
	first.statePath = statePath
	first.grantWorkspace(json.RawMessage(`{"workspace":{"workspace_id":"w1"},"root_pane":{"pane_id":"w1:p1"}}`), "/work/a")

	second := newGuard(filepath.Join(t.TempDir(), "missing.sock"), nil, "claude", "")
	second.statePath = statePath
	second.restoreState()

	if len(second.ownedWorkspaces) != 0 || len(readState(statePath).Workspaces) != 1 {
		t.Error("with herdr unreachable nothing should be granted or pruned")
	}
}
