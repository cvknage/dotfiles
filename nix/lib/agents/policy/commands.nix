{
  # Prefixes include both the bare command and invocations with more arguments.
  ask = [
    "git commit"
    "git branch"
    "git checkout"
    "git clean"
    "git merge"
    "git pull"
    "git rebase"
    "git reset"
    "git switch"
    "git tag"
    "git clone"
    "git config"
    "git init"
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
