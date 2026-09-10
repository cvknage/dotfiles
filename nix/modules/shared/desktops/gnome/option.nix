# Declaration-only; System Manager compositions reference the switch too.
{lib, ...}: {
  options.preferences.desktops.gnome.enable = lib.mkEnableOption "the GNOME desktop environment";
}
