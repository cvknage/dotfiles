{
  inputs,
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  dotfiles = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles";
  easy-dotnet-server = pkgs.buildDotnetGlobalTool {
    pname = "easy-dotnet-server";
    version = "2.3.63 ";
    nugetName = "EasyDotnet";
    nugetHash = "sha256-8ywDdEWxDZUtggvY/2d4Revk09+qb3llymru0Ptpp5c=";
    executables = ["dotnet-easydotnet"];
    dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
  };
  neovimExtraPackages =
    [
      # Needed by lazy.nvim package manager to support luarocks
      pkgs.lua5_1
      pkgs.luajitPackages.luarocks

      # Needed by mason.nvim package manager
      pkgs.unzip
      pkgs.wget

      # Needed by nvim-treesitter to install some languages
      pkgs.gnused

      # Needed by telescope.nvim to do "find" and "live grep"
      pkgs.fd
      pkgs.ripgrep

      # nix code formatter for conform.nvim
      pkgs.alejandra
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      # Needed to install some native dependencies like: nvim-treesitter and fzf-native
      pkgs.gcc
      pkgs.gnumake
    ]
    ++ lib.optionals (config.home.sessionVariables.HOME_CONFIGURATION_CONTEXT == "work") [
      # Needed by easy-dotnet.nvim
      easy-dotnet-server
    ];
in {
  imports = [
    ../../../rust
    ../../modules/home/mcp
    (args:
      inputs.secrets.homeManagerModules.default {
        sops-nix = inputs.sops-nix;
        keyFile = inputs.nixpkgs.lib.mkDefault "${args.config.xdg.configHome}/sops/age/keys.txt";
        secrets = {
          sheet_music = {};
        };
      })
  ];

  home.username = lib.mkDefault user;
  home.homeDirectory = lib.mkDefault (
    if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else "/home/${user}"
  );
  home.packages = [
    pkgs.tmux
    pkgs.git
    pkgs.gitui
    pkgs.jq
    pkgs.gnused
    pkgs.posting
    pkgs.btop
    pkgs.gocryptfs
  ];

  programs.neovim = {
    enable = true;
    vimAlias = true;
    withRuby = true;
    withNodeJs = true;
    withPython3 = true;
    extraPackages = neovimExtraPackages;
    extraWrapperArgs =
      lib.optionals (pkgs.stdenv.isDarwin)
      (lib.concatMap (pkg: [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [pkg])
        ])
        neovimExtraPackages);
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    options = [
      "--cmd cd"
    ];
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    settings = {
      theme = "catppuccin-macchiato";
      autoupdate = true;
      share = "manual";
      permission = {
        external_directory = {
          "*" = "deny";
          "$HOME/.dotfiles/**" = "allow";
          "$HOME/code/**" = "allow";
          "$HOME/Code/**" = "allow";
        };
        bash = {
          "*" = "deny";
          "* ./*" = "allow";
          "* ./**/*" = "allow";

          "git *" = "allow";
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
          "git clone *" = "deny";
          "git config *" = "deny";
          "git init *" = "deny";
          "git worktree *" = "deny";

          "pwd" = "allow";
          "date" = "allow";
          "ls" = "allow";
          "ls -la" = "ask";
          "which *" = "allow";
          "type *" = "allow";
          "echo *" = "allow";

          "task *" = "allow";
          "dotnet *" = "allow";
          "dotnet new *" = "ask";
          "dotnet run *" = "ask";
          "dotnet publish *" = "deny";
          "dotnet store *" = "deny";
          "dotnet workload *" = "deny";
          "dotnet tool install *" = "deny";
          "dotnet tool uninstall *" = "deny";

          "ps" = "ask";
          "jobs" = "ask";
        };
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
    rules = ''
      - Never run `git push`, or any command that modifies a remote repository unless the user explicitly says to do so in the current conversation.

      - Prefer MCP servers and their tools over ad-hoc web searches, curl, or manual parsing when an MCP server is available and relevant to the task.
        Use MCP servers directly when they provide authoritative context (e.g. GitHub MCP for repository access, Azure MCP for Log Analytics).
        Do not probe, crawl, or explore MCP servers beyond what is necessary to fulfill the current user request.

      - Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

      - Always use NixOS MCP when working with *.nix files without me having to explicitly ask.
    '';
  };

  # Enable management of XDG base directories.
  xdg.enable = true;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # symlink to the Nix store copy.
    #  ".screenrc".source = dotfiles/screenrc;

    # You can also set the file content immediately.
    #  ".gradle/gradle.properties".text = ''
    #    org.gradle.console=verbose
    #    org.gradle.daemon.idletimeout=3600000
    #  '';

    # Using the 'mkOutOfStoreSymlink' function it is possible to make 'home.file'
    # create a symlink to a path outside the Nix store.
    # For example, a Home Manager configuration containing:
    #  "foo".source = config.lib.file.mkOutOfStoreSymlink ./bar;
    # would upon activation create a symlink '~/foo' that points to the
    # absolute path of the 'bar' file relative the configuration file.
    "${config.xdg.configHome}/btop".source = "${dotfiles}/btop";
    "${config.xdg.configHome}/direnv/direnv.toml".source = "${dotfiles}/direnv/direnv.toml";
    "${config.xdg.configHome}/direnv/direnvrc".source = "${dotfiles}/direnv/direnvrc";
    "${config.xdg.configHome}/ghostty".source = "${dotfiles}/ghostty";
    "${config.xdg.configHome}/git".source = "${dotfiles}/git";
    "${config.xdg.configHome}/gitui".source = "${dotfiles}/gitui";
    "${config.xdg.configHome}/k9s".source = "${dotfiles}/k9s";
    "${config.xdg.configHome}/kanata".source = "${dotfiles}/kanata";
    "${config.xdg.configHome}/nvim".source = "${dotfiles}/neovim/logic";
    "${config.xdg.configHome}/starship.toml".source = "${dotfiles}/starship/starship.toml";
    "${config.xdg.configHome}/tmux".source = "${dotfiles}/tmux";
    "${config.xdg.configHome}/wezterm".source = "${dotfiles}/wezterm";
    "${config.xdg.configHome}/yazi".source = "${dotfiles}/yazi";
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either:
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  # or
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  # or
  #  /etc/profiles/per-user/chris/etc/profile.d/hm-session-vars.sh
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "ghostty";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.
}
