# Opt-in GNOME desktop, home tier; applies wherever the switch is on.
{
  config,
  dotfiles,
  lib,
  pkgs,
  ...
}: {
  imports = [./option.nix];

  config = lib.mkIf config.preferences.desktops.gnome.enable {
    home.packages = with pkgs; [
      gnomeExtensions.auto-move-windows
      gnomeExtensions.appindicator
    ];

    # Configure GNOME desktop settings using dconf
    dconf.settings = {
      # Select keyboard layout
      "org/gnome/desktop/input-sources" = {
        sources = [
          # "U.S. English (Macintosh, ABC, ANSI)" -- similar to "U.S.
          # International - PC" on macOS, so kanata's and the ZSA Voyager's
          # AltGr combos are the same on both platforms. Standalone Linux
          # uses the stock layout (comes with a working IBus engine); NixOS
          # keeps its own custom us_en_macintosh (nix/systems/nixos.nix),
          # since IBus won't recognize a custom layout by name.
          (lib.hm.gvariant.mkTuple [
            "xkb"
            (
              if config.targets.genericLinux.enable
              then "us+mac"
              else "us_en_macintosh"
            )
          ])
        ];
        xkb-options = [];
      };
      # Enable extensions
      "org/gnome/shell" = {
        disable-user-extensions = false;
        # Use command: `gnome-extensions list` to get extension UUIDs
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
          "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
        ];
      };
      "org/gnome/desktop/background" = {
        picture-uri = "file://${dotfiles}/wallpapers/sun.jpg";
        picture-uri-dark = "file://${dotfiles}/wallpapers/moon.jpg";
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
      };
      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 3;
      };
      "org/gnome/desktop/wm/keybindings" = {
        switch-to-workspace-1 = ["<Super>1"];
        switch-to-workspace-2 = ["<Super>2"];
        switch-to-workspace-3 = ["<Super>3"];
        activate-window-menu = []; # Alt+Space is tmux's prefix, not GNOME's window menu
      };
      # Freed from switch-to-application-1/2/3 so Super+1/2/3 only switch workspaces
      "org/gnome/shell/keybindings" = {
        switch-to-application-1 = [];
        switch-to-application-2 = [];
        switch-to-application-3 = [];
      };
    };
  };
}
