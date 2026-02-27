{
  lib,
  repoScopes,
  ...
}: let
  globalAllow = [
    "git status"
    "git status *"
    "git commit *"
    "git diff"
    "git diff *"
    "git log"
    "git log *"
    "git show *"

    "gh --version"
    "gh version"
    "gh help"
    "gh auth status"
    "gh status"
    "gh repo view"
    "gh repo view *"
    "gh repo list"
    "gh repo list *"
    "gh pr view"
    "gh pr view *"
    "gh pr list"
    "gh pr list *"
    "gh issue view"
    "gh issue view *"
    "gh issue list"
    "gh issue list *"
    "gh search *"

    "pwd"
    "date"
    "which *"
    "type *"
    "echo *"

    "task *"

    "nix eval *"
    "nix fmt *"

    "dotnet *"
  ];

  globalAsk = [
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

    "gh api *"
    "gh pr *"
    "gh issue *"
    "gh repo *"
    "gh release *"
    "gh workflow *"
    "gh run *"
    "gh auth *"

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

  globalDeny = [
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
    "dotnet workload install *"
    "dotnet workload repair *"
    "dotnet workload clean *"
    "dotnet tool install *"
    "dotnet tool uninstall *"
    "dotnet tool update *"
  ];

  fileAllow = [
    "cat"
    "less"
    "head"
    "tail"
    "stat"
    "grep"
    "rg"
    "awk"
    "sed"
  ];

  fileAsk = [
    "find"
    "cp"
    "mv"
    "rm"
  ];

  bareSafe = ["ls"];

  bashRules = patterns: map (pattern: "Bash(${pattern})") patterns;

  # Scope file commands to repoScopes directories
  # Use * for direct children and ** for deeper paths
  scopedBashRules = commands:
    lib.flatten (
      map (dir:
        lib.flatten (
          map (cmd: [
            "Bash(${cmd} ${dir}/*)"
            "Bash(${cmd} ${dir}/**)"
          ])
          commands
        ))
      repoScopes
    );

  fileAccessRules = lib.flatten (map (dir: [
      "Read(${dir}/**)"
      "Edit(${dir}/**)"
      "Write(${dir}/**)"
    ])
    repoScopes);

  permissions = {
    allow =
      (bashRules globalAllow)
      ++ (bashRules bareSafe)
      ++ (scopedBashRules (fileAllow ++ bareSafe))
      ++ fileAccessRules;
    ask =
      (bashRules globalAsk)
      ++ (scopedBashRules fileAsk);
    deny = (bashRules globalDeny) ++ ["Read" "Edit" "Write"];
    additionalDirectories = repoScopes;
  };
in {
  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    settings = {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      inherit permissions;
    };
  };
}
