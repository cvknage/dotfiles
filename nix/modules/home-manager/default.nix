{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./agents
    ./dotfiles-path
    ./git-identity
    ./secrets
  ];

  nix.package = lib.mkDefault pkgs.nix;
}
