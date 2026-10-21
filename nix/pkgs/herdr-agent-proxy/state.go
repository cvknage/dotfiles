package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"syscall"
	"time"
)

// persistedContainer maps each granted pane id to the cwd herdr reported for it at creation, the
// fingerprint checked again before a restored grant is trusted.
type persistedContainer struct {
	Panes map[string]string `json:"panes"`
}

type persistedState struct {
	Workspaces map[string]persistedContainer `json:"workspaces"`
	Tabs       map[string]persistedContainer `json:"tabs"`
}

func (s *persistedState) normalize() {
	if s.Workspaces == nil {
		s.Workspaces = map[string]persistedContainer{}
	}
	if s.Tabs == nil {
		s.Tabs = map[string]persistedContainer{}
	}
}

// persist applies mutate to the on-disk state under an exclusive lock, so several proxies sharing one
// agent kind's file merge their changes instead of overwriting each other.
func (g *guard) persist(mutate func(*persistedState)) {
	if g.statePath == "" {
		return
	}
	lock, err := os.OpenFile(g.statePath+".lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		log.Printf("state lock: %v", err)
		return
	}
	defer lock.Close()
	if syscall.Flock(int(lock.Fd()), syscall.LOCK_EX) != nil {
		return
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	state := readState(g.statePath)
	mutate(&state)
	data, err := json.Marshal(state)
	if err != nil {
		return
	}
	tmp := g.statePath + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		log.Printf("state write: %v", err)
		return
	}
	if err := os.Rename(tmp, g.statePath); err != nil {
		log.Printf("state rename: %v", err)
	}
}

func readState(path string) persistedState {
	var state persistedState
	if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, &state)
	}
	state.normalize()
	return state
}

// restoreState re-grants what an earlier proxy for this agent kind created and herdr still has: a
// container survives only if its id is still listed, and a pane only if it is still listed with the
// cwd recorded at creation, so ids herdr reassigned after a restart don't hand out someone else's panes.
// Nothing is pruned when herdr can't be queried.
func (g *guard) restoreState() {
	if g.statePath == "" {
		return
	}
	state := readState(g.statePath)
	panes, err1 := g.listUpstream("pane.list", "panes", "pane_id")
	tabs, err2 := g.listUpstream("tab.list", "tabs", "tab_id")
	workspaces, err3 := g.listUpstream("workspace.list", "workspaces", "workspace_id")
	if err1 != nil || err2 != nil || err3 != nil {
		log.Printf("restore skipped, herdr not queryable: %v %v %v", err1, err2, err3)
		return
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	var dropWorkspaces, dropTabs []string
	for id, c := range state.Workspaces {
		if _, live := workspaces[id]; !live || !g.restoreContainer(c, panes, g.ownedWorkspaces, g.workspacePanes, id) {
			dropWorkspaces = append(dropWorkspaces, id)
		}
	}
	for id, c := range state.Tabs {
		if _, live := tabs[id]; !live || !g.restoreContainer(c, panes, g.ownedTabs, g.tabPanes, id) {
			dropTabs = append(dropTabs, id)
		}
	}
	g.persist(func(s *persistedState) {
		for _, id := range dropWorkspaces {
			delete(s.Workspaces, id)
		}
		for _, id := range dropTabs {
			delete(s.Tabs, id)
		}
	})
	log.Printf("restored %d workspaces, %d tabs from %s", len(g.ownedWorkspaces), len(g.ownedTabs), g.statePath)
}

func (g *guard) restoreContainer(c persistedContainer, livePanes map[string]string, owned map[string]struct{}, containerPanes map[string][]string, id string) bool {
	var kept []string
	for paneID, cwd := range c.Panes {
		if liveCwd, live := livePanes[paneID]; live && (cwd == "" || cwd == liveCwd) {
			kept = append(kept, paneID)
		}
	}
	if len(kept) == 0 {
		return false
	}
	owned[id] = struct{}{}
	containerPanes[id] = kept
	for _, paneID := range kept {
		g.ownedPanes[paneID] = struct{}{}
	}
	return true
}

// listUpstream returns id -> cwd (empty for non-pane entries) for one of herdr's list methods.
func (g *guard) listUpstream(method, listKey, idKey string) (map[string]string, error) {
	conn, err := net.DialTimeout("unix", g.upstreamPath, 5*time.Second)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	req, _ := json.Marshal(map[string]any{"id": "restore", "method": method, "params": map[string]any{}})
	if _, err := conn.Write(append(req, '\n')); err != nil {
		return nil, err
	}
	var resp struct {
		Result map[string]json.RawMessage `json:"result"`
		Error  json.RawMessage            `json:"error"`
	}
	if err := json.NewDecoder(conn).Decode(&resp); err != nil {
		return nil, err
	}
	var items []map[string]any
	if json.Unmarshal(resp.Result[listKey], &items) != nil {
		return nil, fmt.Errorf("%s: unexpected response", method)
	}
	out := map[string]string{}
	for _, item := range items {
		id, _ := item[idKey].(string)
		cwd, _ := item["cwd"].(string)
		out[id] = cwd
	}
	return out, nil
}
