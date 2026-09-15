{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./agents
    ./dotfiles-path
    ./git-identity
    ./gitui
    ./secrets
  ];

  nix.package = lib.mkDefault pkgs.nix;
}
