{
  config,
  inputs,
  lib,
  ...
}: {
  # Single sops entry point; importers add their own `sops.secrets` on top.
  # Not imported from ./default.nix, so a home without secrets never forces a
  # fetch of the private dotfiles-secrets input.
  imports = [
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

  # Fetch alias for the secrets flake input; IdentitiesOnly keeps ssh from
  # offering account-wide keys.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github-secrets" = {
      hostname = "github.com";
      user = "git";
      identityFile = "${config.home.homeDirectory}/.ssh/dotfiles-secrets";
      identitiesOnly = true;
    };
  };
}
