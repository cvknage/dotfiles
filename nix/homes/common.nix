{
  config,
  lib,
  pkgs,
  ...
}: let
  dotfiles = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles";
in {
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
    # shared between all
    ../../rust
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Developer Tools
    pkgs.tmux
    pkgs.git
    pkgs.gitui
    pkgs.jq
    pkgs.gnused
    pkgs.posting
    pkgs.btop
  ];

  programs.neovim = {
    enable = true;
    vimAlias = true;
    extraPackages =
      [
        # needed for lazy.nvim package manager to work corerctly
        pkgs.lua5_1
        pkgs.luajitPackages.luarocks

        # needed for mason.nvim package manager to work correctly
        pkgs.unzip
        pkgs.wget

        # needed for nvim-treesitter to install some languages
        pkgs.gnused

        # needed for telescope.nvim to do "find" and "live grep"
        pkgs.fd
        pkgs.ripgrep

        # nix code formatter for conform.nvim
        pkgs.alejandra

        # needed for copilot.lua
        pkgs.nodejs_latest
      ]
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [
        # needed for nvim to install nvim-treesitter and fzf-native
        pkgs.gcc
        pkgs.gnumake
      ];
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
    XDG_CONFIG_HOME = "${config.xdg.configHome}";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
