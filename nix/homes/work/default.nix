{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  easyeffectsWrapped = pkgs.symlinkJoin {
    name = "easyeffects-wrapped";
    paths = [pkgs.easyeffects];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      gtk3Schemas="$(echo ${pkgs.gtk3}/share/gsettings-schemas/*)"
      gsdSchemas="$(echo ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/*)"

      wrapProgram $out/bin/easyeffects \
        --prefix XDG_DATA_DIRS : "$gtk3Schemas:$gsdSchemas"
    '';
  };
in {
  imports = [
    ../../modules/home/another-redis-desktop-manager
    # ../../modules/home/claude-desktop
    ../../modules/home/outlook
    ./git-signing.nix
    ./global-dev-tools.nix # Globally installed development tools - prefer project local tooling
  ];

  sops.secrets =
    {
      mutation_strings = {};
    }
    // inputs.nixpkgs.lib.genAttrs [
      "docker_registry_hostname"
      "github_user"
      "github_token"
      "email"
      "public_key"
    ] (_: {sopsFile = "${inputs.secrets.outPath}/secrets/homes/work/secrets.yaml";});

  home.packages = [
    pkgs.gnomeExtensions.auto-move-windows
    pkgs.gnomeExtensions.appindicator

    pkgs.slack
    pkgs.stable.teams-for-linux
    easyeffectsWrapped # pkgs.easyeffects

    pkgs.ghostty
    pkgs.postman
    pkgs.git-cliff
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      ${builtins.readFile ../../../shell/bash/config}
      ${builtins.readFile ../../../shell/colours}
      ${builtins.readFile ../../../shell/prompt}

      ${builtins.readFile ../../../shell/common}

      if prompt_is_fancy_terminal && command -v starship >/dev/null; then
        eval "$(starship init bash)"
      else
        ${builtins.readFile ../../../shell/bash/PS1}
      fi

      export DOCKER_REGISTRY_HOSTNAME="$(cat ${config.sops.secrets.docker_registry_hostname.path})"
      export GITHUB_USER="$(cat ${config.sops.secrets.github_user.path})"
      export GITHUB_TOKEN="$(cat ${config.sops.secrets.github_token.path})"
      export GH_TOKEN="$(cat ${config.sops.secrets.github_token.path})"
      export GITHUB_PAT="$(cat ${config.sops.secrets.github_token.path})"
      export GITHUB_REPO_PAT="$(cat ${config.sops.secrets.github_token.path})"
      export NIX_CONFIG="access-tokens = github.com/secomea-dev=$GITHUB_TOKEN"

      alias mnotes='gocryptfs ~/Notes.encrypted ~/Notes'
      alias unotes='fusermount -u ~/Notes'
    '';
    profileExtra = ''
    '';
  };

  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
  };
  programs.chromium = {
    enable = true;
    package = pkgs.stable.ungoogled-chromium;
  };

  # Chromium stopped generating its own desktop icon, so add it manually
  # xdg.desktopEntries.chromium = {
  #   name = "Chromium";
  #   exec = "chromium %U";
  #   icon = "chromium";
  #   categories = ["Network" "WebBrowser"];
  # };

  # Configure GNOME desktop settings using dconf
  dconf = {
    settings = {
      # Select keyboard layout
      "org/gnome/desktop/input-sources" = {
        sources = [
          # "U.S. English (Macintosh, ABC, ANSI)" -- similar to "U.S.
          # International - PC" on macOS, so kanata's and the ZSA Voyager's
          # AltGr combos are the same on both platforms. Standalone Linux
          # uses the stock layout (comes with a working IBus engine); NixOS
          # keeps its own custom us_en_macintosh (hosts/penguin-tuxedo),
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
        # Dash pinned apps -- dconf resets anything set by hand on every switch
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "com.mitchellh.ghostty.desktop"
          "firefox.desktop"
          "slack.desktop"
          "teams-for-linux.desktop"
          "FFPWA-3ZPKFCVA6N628YZFAFDB2MVRPN.desktop" # Outlook PWA
        ];
      };
      "org/gnome/desktop/background" = {
        picture-uri = "file://${config.home.homeDirectory}/.dotfiles/wallpapers/sun.jpg";
        picture-uri-dark = "file://${config.home.homeDirectory}/.dotfiles/wallpapers/moon.jpg";
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
      # Pin apps to workspaces (auto-move-windows extension, enabled above)
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
  };

  # Launch on login
  xdg.autostart.enable = true;
  xdg.autostart.entries = [
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

  home.sessionVariables = {
    HOME_CONFIGURATION_CONTEXT = "work";
  };
}
