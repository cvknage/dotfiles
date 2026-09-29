{
  config,
  inputs,
  ...
}: let
  alias = import ../../../lib/secrets-alias.nix config.home.homeDirectory;
in {
  imports = [
    (inputs.secrets.homeManagerModules.default {
      sops-nix = inputs.sops-nix;
      keyFile = "${config.home.homeDirectory}/.ssh/keys/dotfiles-secrets-pq";
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
}
