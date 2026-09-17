package main

import (
	"os"
	"path/filepath"
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

func TestCheckContainerCreateRejectsAncestorMount(t *testing.T) {
	base := t.TempDir()
	home := filepath.Join(base, "home")
	alias := filepath.Join(base, "home-alias")
	if err := os.MkdirAll(filepath.Join(home, ".config", "sops-nix"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(home, alias); err != nil {
		t.Fatal(err)
	}
	denied := []string{filepath.Join(alias, ".config", "sops-nix")}

	// Mounting the home directory exposes the denied path without naming it.
	body := []byte(`{"HostConfig":{"Binds":["` + home + `:/host"]}}`)
	if reason := checkContainerCreate(body, denied); reason == "" {
		t.Fatalf("bind of %q exposed the denied path but was not rejected", home)
	}

	body = []byte(`{"HostConfig":{"Mounts":[{"Type":"bind","Source":"` + home + `","Target":"/host"}]}}`)
	if reason := checkContainerCreate(body, denied); reason == "" {
		t.Fatalf("bind mount of %q exposed the denied path but was not rejected", home)
	}

	// A project directory that contains no denied path still passes.
	project := filepath.Join(home, "code", "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	body = []byte(`{"HostConfig":{"Binds":["` + project + `:/src"]}}`)
	if reason := checkContainerCreate(body, denied); reason != "" {
		t.Fatalf("ordinary project mount was rejected: %s", reason)
	}
}
