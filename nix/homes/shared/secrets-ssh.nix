{config, ...}: let
  alias = import ../../modules/shared/secrets-ssh-alias.nix config.home.homeDirectory;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings.${alias.host} = alias.settings;
  };
}
