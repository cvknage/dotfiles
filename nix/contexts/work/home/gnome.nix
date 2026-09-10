# GNOME-specific bits for the work home: app pins, autostart, and the desktop
# entries that keep the GNOME app grid tidy. Imported only when the
# composition's preferences.desktops.gnome switch is on.
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.preferences.desktops.gnome.enable {
    # Ghostty's DBusActivatable=true routes launches through systemd's UnitPath,
    # which never picks up the Home Manager profile (locked in at manager
    # startup, before environment.d ever runs). Drop it so the icon just execs
    # directly; only relevant where the home tier is a standalone Home Manager
    # profile (targets.genericLinux).
    home.file."${config.xdg.dataHome}/applications/com.mitchellh.ghostty.desktop" = lib.mkIf config.targets.genericLinux.enable {
      text = ''
        [Desktop Entry]
        Version=1.0
        Name=Ghostty
        Type=Application
        Comment=A terminal emulator
        TryExec=ghostty
        Exec=ghostty --gtk-single-instance=true
        Icon=com.mitchellh.ghostty
        Categories=System;TerminalEmulator;
        Keywords=terminal;tty;pty;
        StartupNotify=true
        StartupWMClass=com.mitchellh.ghostty
        Terminal=false
        Actions=new-window;
        X-GNOME-UsesNotifications=true
        X-TerminalArgExec=-e
        X-TerminalArgTitle=--title=
        X-TerminalArgAppId=--class=
        X-TerminalArgDir=--working-directory=
        X-TerminalArgHold=--wait-after-command
        X-KDE-Shortcuts=Ctrl+Alt+T

        [Desktop Action new-window]
        Name=New Window
        Exec=ghostty --gtk-single-instance=true
      '';
    };

    # Dash pinned apps -- dconf resets anything set by hand on every switch
    dconf.settings = {
      "org/gnome/shell" = {
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "com.mitchellh.ghostty.desktop"
          "firefox.desktop"
          "slack.desktop"
          "teams-for-linux.desktop"
          "FFPWA-3ZPKFCVA6N628YZFAFDB2MVRPN.desktop" # Outlook PWA
        ];
      };
      # Pin apps to workspaces (auto-move-windows extension)
      "org/gnome/shell/extensions/auto-move-windows" = {
        application-list = [
          "com.mitchellh.ghostty.desktop:1"
          "firefox.desktop:2"
          "chromium-browser.desktop:2"
          "slack.desktop:3"
          "teams-for-linux.desktop:3"
          "FFPWA-3ZPKFCVA6N628YZFAFDB2MVRPN.desktop:3" # Outlook PWA
        ];
      };
    };

    # Launch on login
    xdg.autostart = {
      enable = true;
      entries = [
        (
          if config.targets.genericLinux.enable
          then "${config.xdg.dataHome}/applications/com.mitchellh.ghostty.desktop"
          else "${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop"
        )
        "${config.programs.firefox.finalPackage}/share/applications/firefox.desktop"
        "${pkgs.slack}/share/applications/slack.desktop"
        "${pkgs.stable.teams-for-linux}/share/applications/teams-for-linux.desktop"
        "${config.home.homeDirectory}/.nix-profile/share/applications/FFPWA-3ZPKFCVA6N628YZFAFDB2MVRPN.desktop" # Outlook PWA
      ];
    };

    # Drop from GNOME's app grid and search
    xdg.desktopEntries = {
      firefoxpwa = {
        name = "firefoxpwa";
        noDisplay = true;
      };
      nvim = {
        name = "Neovim wrapper";
        noDisplay = true;
      };
      yazi = {
        name = "Yazi File Manager";
        noDisplay = true;
      };
      btop = {
        name = "btop++";
        noDisplay = true;
      };
    };
  };
}
