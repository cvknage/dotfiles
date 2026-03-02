{
  lib,
  repoScopes,
  ...
}: let
  sharedPermissions = import ../agents/command-permissions.nix;
  permissionsLib = import ../agents/permissions-lib.nix {inherit lib;};

  scopedPathRules = permissionsLib.mkOpencodeScopedPathRules repoScopes;

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
          (permissionsLib.mkOpencodeBashPermissions sharedPermissions)
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
