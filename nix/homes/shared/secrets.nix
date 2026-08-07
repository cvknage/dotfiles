{
  config,
  inputs,
  lib,
  ...
}: {
  # Single sops entry point; importers add their own `sops.secrets` on top.
  imports = [
    ./secrets-ssh.nix
    (inputs.secrets.homeManagerModules.default {
      sops-nix = inputs.sops-nix;
      keyFile = null;
      secrets = {
        sheet_music = {};
      };
    })
  ];

  # The deploy key created by ../../secrets-bootstrap.sh is also the age
  # identity; sops-nix converts it at activation.
  sops.age = {
    sshKeyPaths = ["${config.home.homeDirectory}/.ssh/dotfiles-secrets"];
    generateKey = lib.mkForce false;
  };
}
