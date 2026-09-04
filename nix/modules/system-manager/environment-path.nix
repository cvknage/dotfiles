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
  # session on the machine, sudo's and the unprivileged gdm-greeter account's
  # included), which does no variable substitution at all -- so every session got
  # that text verbatim as PATH, and even /usr/bin disappeared. Neutralize it here;
  # the real values live in 05-system-manager.conf below.
  environment.etc."environment.d/10-system-manager.conf".text = lib.mkForce "";

  # environment.d files are read in lexical filename order across /etc and
  # ~/.config, each entry a plain overwrite rather than a merge. This file is
  # named to sort before Home Manager's own
  # ~/.config/environment.d/10-home-manager.conf ("05-system-manager" <
  # "10-home-manager"), so that file's PATH/XDG_DATA_DIRS -- which correctly
  # includes the Home Manager profile, ~/.nix-profile -- wins for this user's
  # own sessions. Every other account on the machine (which has no such
  # per-user file, e.g. the unprivileged gdm-greeter account that renders the
  # login screen) keeps just the values below. Do NOT add ~/.nix-profile here:
  # that previously broke gdm-greeter's own session (permission denied opening
  # this user's home directory) because this file applies to every session,
  # not just this user's.
  environment.etc."environment.d/05-system-manager.conf".text = ''
    ${lib.concatLines (lib.mapAttrsToList (k: v: ''${k}="${v}"'') config.environment.variables)}
    PATH=/etc/profiles/per-user/${user}/bin:${pathDir}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    XDG_DATA_DIRS=/etc/profiles/per-user/${user}/share:${pathDir}/share:/usr/local/share:/usr/share
  '';
}
