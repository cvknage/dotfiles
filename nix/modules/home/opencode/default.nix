{
  config,
  lib,
  pkgs,
  ...
}: let
  repoScopes =
    [
      "${config.home.homeDirectory}/.dotfiles"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/Code"
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      "${config.home.homeDirectory}/code"
    ];

  scopedPathRules =
    lib.foldl' lib.recursiveUpdate
    {
      "* ." = "allow";
      "* ./**" = "allow";
    }
    (map
      (dir: {
        "* ${dir}" = "allow";
        "* ${dir}/**" = "allow";
      })
      repoScopes);

  externalDirectoryRules = lib.foldl' lib.recursiveUpdate {"*" = "deny";} (map
    (dir: {
      "${dir}" = "allow";
      "${dir}/**" = "allow";
    })
    repoScopes);
in {
  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    themes = {
      catppuccin-macchiato-transparent = {
        defs = {
          blue = "#8aadf4";
          mauve = "#c6a0f6";
          peach = "#f5a97f";
          red = "#ed8796";
          green = "#a6da95";
          sky = "#91d7e3";
          teal = "#8bd5ca";
          text = "#cad3f5";
          subtext0 = "#a5adcb";
          subtext1 = "#b8c0e0";
          overlay0 = "#6e738d";
          overlay1 = "#8087a2";
          overlay2 = "#939ab7";
          surface0 = "#363a4f";
          surface1 = "#494d64";
        };
        theme = {
          primary = "blue";
          secondary = "mauve";
          accent = "peach";
          error = "red";
          warning = "peach";
          success = "green";
          info = "blue";
          text = "text";
          textMuted = "subtext0";
          background = "none";
          backgroundPanel = "none"; #"surface0";
          backgroundElement = "none"; #"surface1";
          border = "overlay0";
          borderActive = "blue";
          borderSubtle = "overlay1";
          diffAdded = "green";
          diffRemoved = "red";
          diffContext = "overlay1";
          diffHunkHeader = "overlay2";
          diffHighlightAdded = "green";
          diffHighlightRemoved = "red";
          diffAddedBg = "none";
          diffRemovedBg = "none";
          diffContextBg = "none";
          diffLineNumber = "overlay0";
          diffAddedLineNumberBg = "surface1";
          diffRemovedLineNumberBg = "surface1";
          markdownText = "text";
          markdownHeading = "mauve";
          markdownLink = "sky";
          markdownLinkText = "peach";
          markdownCode = "green";
          markdownBlockQuote = "overlay1";
          markdownEmph = "peach";
          markdownStrong = "peach";
          markdownHorizontalRule = "overlay0";
          markdownListItem = "blue";
          markdownListEnumeration = "sky";
          markdownImage = "blue";
          markdownImageText = "peach";
          markdownCodeBlock = "text";
          syntaxComment = "overlay1";
          syntaxKeyword = "mauve";
          syntaxFunction = "green";
          syntaxVariable = "sky";
          syntaxString = "peach";
          syntaxNumber = "teal";
          syntaxType = "sky";
          syntaxOperator = "mauve";
          syntaxPunctuation = "text";
        };
      };
    };
    settings = {
      theme = "catppuccin-macchiato-transparent";
      autoupdate = true;
      share = "manual";
      permission = {
        external_directory = externalDirectoryRules;
        bash =
          lib.recursiveUpdate
          {
            "*" = "deny";

            "git status" = "allow";
            "git status *" = "allow";
            "git commit *" = "allow";
            "git diff" = "allow";
            "git diff *" = "allow";
            "git log" = "allow";
            "git log *" = "allow";
            "git show *" = "allow";
            "git branch *" = "ask";
            "git checkout *" = "ask";
            "git clean *" = "ask";
            "git merge *" = "ask";
            "git pull *" = "ask";
            "git push *" = "ask";
            "git rebase *" = "ask";
            "git reset *" = "ask";
            "git switch *" = "ask";
            "git tag *" = "ask";
            "git -C *" = "deny";
            "git clone *" = "deny";
            "git config *" = "deny";
            "git init *" = "deny";
            "git worktree *" = "deny";

            "gh --version" = "allow";
            "gh version" = "allow";
            "gh help" = "allow";
            "gh auth status" = "allow";
            "gh status" = "allow";
            "gh repo view" = "allow";
            "gh repo view *" = "allow";
            "gh repo list" = "allow";
            "gh repo list *" = "allow";
            "gh pr view" = "allow";
            "gh pr view *" = "allow";
            "gh pr list" = "allow";
            "gh pr list *" = "allow";
            "gh issue view" = "allow";
            "gh issue view *" = "allow";
            "gh issue list" = "allow";
            "gh issue list *" = "allow";
            "gh search *" = "allow";
            "gh api *" = "ask";
            "gh pr *" = "ask";
            "gh issue *" = "ask";
            "gh repo *" = "ask";
            "gh release *" = "ask";
            "gh workflow *" = "ask";
            "gh run *" = "ask";
            "gh auth *" = "ask";

            "pwd" = "allow";
            "date" = "allow";
            "ls" = "allow";
            "ls -la" = "ask";
            "which *" = "allow";
            "type *" = "allow";
            "echo *" = "allow";

            "cat *" = "allow";
            "less *" = "allow";
            "head *" = "allow";
            "tail *" = "allow";
            "stat *" = "allow";
            "grep *" = "allow";
            "rg *" = "allow";
            "awk *" = "allow";
            "sed *" = "allow";
            "find *" = "ask";

            "cp ./**" = "ask";
            "mv ./**" = "ask";
            "rm ./**" = "ask";

            "task *" = "allow";
            "curl *" = "ask";

            "nix eval *" = "allow";
            "nix fmt *" = "allow";
            "nix flake check *" = "ask";
            "nix build *" = "ask";
            "nix develop *" = "ask";
            "nix run *" = "ask";
            "nix profile *" = "deny";
            "nix profile install *" = "deny";
            "nix profile remove *" = "deny";
            "nix-env *" = "deny";
            "nix channel *" = "deny";

            "dotnet *" = "allow";
            "dotnet new *" = "ask";
            "dotnet run *" = "ask";
            "dotnet publish *" = "deny";
            "dotnet store *" = "deny";
            "dotnet workload *" = "deny";
            "dotnet workload update *" = "deny";
            "dotnet workload install *" = "deny";
            "dotnet workload repair *" = "deny";
            "dotnet workload restore *" = "ask";
            "dotnet workload clean *" = "deny";
            "dotnet tool install *" = "deny";
            "dotnet tool uninstall *" = "deny";
            "dotnet tool update *" = "deny";

            "ps" = "ask";
            "ps *" = "ask";
            "jobs" = "ask";
          }
          scopedPathRules;
      };
      formatter = {
        nixfmt.disabled = true;
        alejandra = {
          command = ["alejandra" "$FILE"];
          extensions = [".nix"];
        };
        stylua = {
          command = ["stylua" "$FILE"];
          extensions = [".lua"];
        };
        shfmt = {
          command = ["shfmt" "-i" "2" "-ci" "-w" "$FILE"];
          extensions = [".sh" ".bash" ".zsh"];
        };
        taplo = {
          command = ["taplo" "format" "$FILE"];
          extensions = [".toml"];
        };
        csharpier = {
          command = ["dotnet" "csharpier" "format" "$FILE"];
          extensions = [".cs" ".xml"];
        };
      };
    };
  };
}
