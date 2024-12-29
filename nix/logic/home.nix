{ inputs, config, pkgs, user, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = user;
  home.homeDirectory = "/Users/${user}";

  imports = [
    # shared between all
    ../common.nix 

    # specific to home
    ../../shell/zsh.nix
    ../../yazi/yazi.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.neovim
    pkgs.tmux
    pkgs.gitui

    pkgs.hugo

    pkgs.fd
    pkgs.jq
    pkgs.gnused
    pkgs.ripgrep
    pkgs.lua5_1
    pkgs.luajitPackages.luarocks
    pkgs.nodejs_latest

    inputs.wezterm.packages.${pkgs.system}.default # https://wezfurlong.org/wezterm/install/linux.html#flake
    # inputs.ghostty.packages.${pkgs.system}.default # ghostty flake does not currently support aarch64-darwin
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/chris/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
