{
  config,
  inputs,
  lib,
  ...
}: let
  alias = import ../../shared/secrets/alias.nix config.home.homeDirectory;
in {
  imports = [
    (inputs.secrets.homeManagerModules.default {
      sops-nix = inputs.sops-nix;
      keyFile = null;
      secrets = {
        sheet_music = {};
      };
    })
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings.${alias.host} = alias.settings;
  };

  # The deploy key is also the age identity; sops-nix converts it at activation.
  sops.age = {
    sshKeyPaths = ["${config.home.homeDirectory}/.ssh/keys/dotfiles-secrets"];
    generateKey = lib.mkForce false;
  };
}
