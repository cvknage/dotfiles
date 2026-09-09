{
  lib,
  pkgs,
  ...
}: {
  nix.package = lib.mkDefault pkgs.nix;
}
