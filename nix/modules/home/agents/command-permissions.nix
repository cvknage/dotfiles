{
  bash = {
    allow = [
      "git status"
      "git status *"
      "git diff"
      "git diff *"
      "git log"
      "git log *"
      "git show *"

      "gh --version"
      "gh version"
      "gh help"
      "gh api *"
      "gh auth status"
      "gh status"
      "gh repo *"
      "gh pr *"
      "gh issue *"
      "gh search *"

      "pwd"
      "date"
      "ls"
      "which *"
      "type *"
      "echo *"

      "task *"

      "nix eval *"
      "nix fmt *"

      "dotnet *"
      "swift *"
      "xcode *"
    ];

    ask = [
      "git commit *"
      "git branch *"
      "git checkout *"
      "git clean *"
      "git merge *"
      "git pull *"
      "git push *"
      "git rebase *"
      "git reset *"
      "git switch *"
      "git tag *"

      "gh release *"
      "gh workflow *"
      "gh run *"
      "gh auth *"

      "ls -la"
      "curl *"

      "nix flake check *"
      "nix build *"
      "nix develop *"
      "nix run *"

      "dotnet new *"
      "dotnet run *"
      "dotnet workload restore *"

      "ps"
      "ps *"
      "jobs"
    ];

    deny = [
      "cd"
      "cd *"
      "pushd *"
      "popd"
      "popd *"
      "dirs"
      "dirs *"
      "*../*"

      "git -C *"
      "git clone *"
      "git config *"
      "git init *"
      "git worktree *"

      "nix profile *"
      "nix profile install *"
      "nix profile remove *"
      "nix-env *"
      "nix channel *"

      "dotnet publish *"
      "dotnet store *"
      "dotnet workload *"
      "dotnet workload update *"
      "dotnet tool install *"
      "dotnet tool uninstall *"
      "dotnet tool update *"
    ];
  };
}
