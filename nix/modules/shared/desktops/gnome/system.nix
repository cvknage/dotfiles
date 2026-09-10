# Opt-in GNOME desktop, system tier; one switch drives the home tier too.
{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [./option.nix];

  config = lib.mkIf config.preferences.desktops.gnome.enable {
    # Enable the GNOME Desktop Environment.
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Exclude default GNOME Applications.
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour # tour app
      gnome-contacts # contacts app
      gnome-music # music player
      geary # email reader
    ];

    # Enable dconf for managing GNOME settings
    programs.dconf.enable = true;

    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # One switch drives the home tier too; see home.nix.
    home-manager.users.${user}.preferences.desktops.gnome.enable = true;
  };
}
