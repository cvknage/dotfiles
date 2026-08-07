{
  lib,
  pkgs,
  user,
  ...
}: let
  alias = import ./secrets-ssh-alias.nix (
    if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else "/home/${user}"
  );
in {
  programs.ssh.extraConfig = lib.concatLines (
    ["Host ${alias.host}"]
    ++ lib.mapAttrsToList (name: value: "  ${name} ${value}") alias.settings
  );
}
