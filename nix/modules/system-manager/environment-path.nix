{
  config,
  lib,
  user,
  ...
}: let
  # Mirrors the private `pathDir` in system-manager's own environment.nix.
  pathDir = "/run/system-manager/sw";
in {
  # system-manager's environment.nix writes /etc/environment.d/10-system-manager.conf
  # with literal ${USER}/${PATH} placeholders, expecting shell-style expansion. But
  # environment.d files are parsed by systemd itself (used for every PAM-managed
  # session, sudo's included), which does no variable substitution at all -- so every
  # session gets that text verbatim as PATH, and even /usr/bin disappears. This
  # overrides the file with a fully resolved PATH and XDG_DATA_DIRS instead, using
  # one Nix substitution rather than two shell ones systemd will never expand.
  environment.etc."environment.d/10-system-manager.conf".text = lib.mkForce ''
    ${lib.concatLines (lib.mapAttrsToList (k: v: ''${k}="${v}"'') config.environment.variables)}
    PATH=/etc/profiles/per-user/${user}/bin:${pathDir}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    XDG_DATA_DIRS=/etc/profiles/per-user/${user}/share:${pathDir}/share:/usr/local/share:/usr/share
  '';
}
