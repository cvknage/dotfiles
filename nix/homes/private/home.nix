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
    ../../../shell/zsh.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Developer Tools
    pkgs.hugo
    pkgs.ollama
  ];
}
