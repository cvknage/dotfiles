{
  inputs,
  pkgs,
  user,
  ...
}: let
  # Create combined package of dotnet SDKs
  combinedDotNetSDKs = pkgs.buildEnv {
    name = "combinedDotNetSDKs";
    paths = [
      (
        with pkgs.dotnetCorePackages;
          combinePackages [
            sdk_9_0
            sdk_7_0
          ]
      )
    ];
  };
in {
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
    # pkgs.ghostty # perfer ghostty from its own repo
    inputs.ghostty.packages.${pkgs.system}.default
    pkgs.postman
    pkgs.azure-cli
    pkgs.kubelogin
    pkgs.kubectl
    pkgs.kind
    pkgs.kubernetes-helm
    pkgs.go-task
    pkgs.k9s
    pkgs.mirrord
    pkgs.gh
    pkgs.k6
    pkgs.biome

    # SDKs
    combinedDotNetSDKs
    pkgs.python3
    pkgs.corepack
    pkgs.bun
    pkgs.deno
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
    DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
}
