{ inputs, config, pkgs, user, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = user;
  home.homeDirectory = "/home/${user}";

  imports = [
    # shared between all
    ../common.nix

    # specific to home
    ../../../shell/bash.nix
    ../../modules/AnotherRedisDesktopManager/another-redis-desktop-manager.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Office Tools
    pkgs.slack
    pkgs.teams-for-linux
    pkgs.buttercup-desktop

    # Developer Tools
    # pkgs.ghostty # perfer ghostty from its own repo
    inputs.ghostty.packages.${pkgs.system}.default
    pkgs.postman
    pkgs.docker
    pkgs.azure-cli
    pkgs.kubelogin
    pkgs.kubectl
    pkgs.kind
    pkgs.kubernetes-helm
    pkgs.go-task
    pkgs.k9s
    pkgs.mirrord

    # SDKs
    pkgs.dotnetCorePackages.dotnet_9.sdk

    # gcc & make needed for nvim to install tresitter and fzf-native
    pkgs.gcc
    pkgs.gnumake
  ];
}
