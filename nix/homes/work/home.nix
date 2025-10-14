{
  # inputs,
  lib,
  pkgs,
  user,
  ...
}:
# Install dotnet globally
/*
}: let
  # Create combined package of dotnet SDKs
  combinedDotNetSDKs = pkgs.buildEnv {
    name = "combinedDotNetSDKs";
    paths = [
      (
        with pkgs.dotnetCorePackages;
          combinePackages [
            sdk_9_0
          ]
      )
    ];
  };
in {
*/
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = user;
  home.homeDirectory = "/home/${user}";

  imports = [
    # shared between all
    ../common.nix

    # specific to home
    ../../modules/AnotherRedisDesktopManager/another-redis-desktop-manager.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Gnome extensions
    pkgs.gnomeExtensions.auto-move-windows
    pkgs.gnomeExtensions.appindicator
    pkgs.gnomeExtensions.easyeffects-preset-selector

    # Office Tools
    pkgs.slack
    pkgs.teams-for-linux
    pkgs.buttercup-desktop
    pkgs.easyeffects

    # Developer Tools
    pkgs.ghostty # perfer ghostty from its own repo
    # inputs.ghostty.packages.${pkgs.system}.default
    pkgs.postman
    pkgs.biome

    # SDKs
    pkgs.corepack
    pkgs.bun
    pkgs.deno

    # General Work Tooling
    # Moved work related tooling in to nix profiles and nix devshell that the whole team can use

    # nix profile install "github:secomea-dev/recipes?dir=dev-tools/core"
    # pkgs.azure-cli
    # pkgs.kubelogin
    # pkgs.kubectl
    # pkgs.kind
    # pkgs.kubernetes-helm
    # pkgs.go-task
    # pkgs.k9s
    # pkgs.mirrord
    # pkgs.gh
    # pkgs.k6
    # pkgs.python3

    # nix profile install "github:secomea-dev/recipes?dir=dev-tools/dotnet"
    # combinedDotNetSDKs
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      # ''${builtins.readFile ../../../shell/bash/PS1}
      ${builtins.readFile ../../../shell/bash/config}
      ${builtins.readFile ../../../shell/colours}

      ${builtins.readFile ../../../shell/common}

      CUSTOM_VARIABLES="$HOME/.custom-variables"
      if [ -f "$CUSTOM_VARIABLES" ]; then
        . "$CUSTOM_VARIABLES"
      fi

      # Started getting the message below when using zoxide:
      # zoxide: detected a possible configuration issue.
      # Please ensure that zoxide is initialized right at the end of your shell configuration file (usually ~/.bashrc).
      #
      # If the issue persists, consider filing an issue at:
      # https://github.com/ajeetdsouza/zoxide/issues
      #
      # Disable this message by setting _ZO_DOCTOR=0.
      _ZO_DOCTOR=0
    '';
    profileExtra = ''
    '';
  };

  programs.firefox.enable = true;

  # Configure GNOME desktop settings using dconf
  dconf = {
    settings = {
      # Select keyboard layout
      "org/gnome/desktop/input-sources" = {
        sources = [
          # Laout should to be: "U.S. English (Macintosh)" which is simila to "U.S. Internationl - PC" layout on Mac.
          # This makes using Kanata and ZSA Voyager the same experience on both platforms.
          # The "us+mac" layout used to work, but '`' (grave) and '§' (section) keys got swapped in a NixOS update:
          # (lib.hm.gvariant.mkTuple ["xkb" "us+mac"])
          (lib.hm.gvariant.mkTuple ["xkb" "us_en_macintosh"]) # Use custom "U.S. English (Macintosh)" layout.
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
          "eepresetselector@ulville.github.io"
        ];
      };
    };
  };

  home.sessionVariables = {
    # DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
}
