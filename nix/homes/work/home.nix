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
    pkgs.slack
    pkgs.teams-for-linux
    pkgs.postman
    pkgs.buttercup-desktop

    # pkgs.ghostty
    inputs.ghostty.packages.${pkgs.system}.default

    pkgs.dotnetCorePackages.dotnet_9.sdk
    pkgs.docker
    pkgs.azure-cli
    pkgs.kubelogin
    pkgs.kubectl
    pkgs.kind
    pkgs.kubernetes-helm
    pkgs.go-task
    pkgs.k9s
    pkgs.mirrord

    # gcc & make needed for nvim to install tresitter and fzf-native
    pkgs.gcc
    pkgs.gnumake
  ];
}
