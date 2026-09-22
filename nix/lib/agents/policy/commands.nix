{
  # Prefixes include both the bare command and invocations with more arguments.
  ask = [
    "git branch"
    "git checkout"
    "git clean"
    "git reset"
    "git restore"
    "git stash clear"
    "git stash drop"
    "git config"
    "git remote"
    "git worktree"

    "gh release"
    "gh workflow"
    "gh auth login"
    "gh auth logout"
    "gh auth refresh"
    "gh auth setup-git"
    "gh auth switch"
    "gh auth token"
  ];

  deny = [
    "sudo"

    "git push"

    "gh release delete"
    "gh repo archive"
    "gh repo delete"
    "gh repo sync"

    "nix profile"
    "nix-env"
    "nix channel"
    "nix-shell -p"
    "nix-shell --packages"
    "nix run"
    "nix shell"

    "darwin-rebuild"
    "nixos-rebuild"
    "fedora-rebuild"
    "home-manager"
    "system-manager"

    "dotnet store"
    "dotnet workload update"
    "dotnet tool install"
    "dotnet tool uninstall"
    "dotnet tool update"
  ];
}
