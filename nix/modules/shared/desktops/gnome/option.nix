# Declaration-only; System Manager compositions reference the switch too.
{lib, ...}: {
  options.dotfiles.desktops.gnome.enable = lib.mkEnableOption "the GNOME desktop environment";
}
