{
  config,
  lib,
  user,
  ...
}: let
  # Mirrors the private `pathDir` in system-manager's own environment.nix.
  pathDir = "/run/system-manager/sw";
in {
  # Upstream's file has unexpanded ${USER}/${PATH} placeholders that
  # environment.d never expands, breaking PATH for every PAM session.
  # Neutralized; real values live in 05-system-manager.conf below.
  environment.etc."environment.d/10-system-manager.conf".text = lib.mkForce "";

  # Sorted to load before Home Manager's 10-home-manager.conf, so this file
  # doesn't overwrite its ~/.nix-profile entry. This file applies to every
  # account, including gdm-greeter -- adding ~/.nix-profile directly here
  # instead once broke its session.
  environment.etc."environment.d/05-system-manager.conf".text = ''
    ${lib.concatLines (lib.mapAttrsToList (k: v: ''${k}="${v}"'') config.environment.variables)}
    PATH=/etc/profiles/per-user/${user}/bin:${pathDir}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    XDG_DATA_DIRS=/etc/profiles/per-user/${user}/share:${pathDir}/share:/usr/local/share:/usr/share
  '';
}
