{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:
/*
# Global .NET installation
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
    ../../modules/OutlookPWA/outlook.nix
    (args:
      inputs.secrets.homeManagerModules.default {
        sops-nix = inputs.sops-nix;
        keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        secrets =
          {
            mutation_strings = {};
          }
          // inputs.nixpkgs.lib.genAttrs [
            "docker_registry_hostname"
            "github_user"
            "github_token"
            "gh_token"
          ] (_: {sopsFile = "${inputs.secrets.outPath}/secrets/homes/work/secrets.yaml";});
      })
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
    pkgs.ghostty
    pkgs.postman

    # General work tooling is moved to nix profiles and nix devShell
    # Globally installed tools
    # `nix profile install "github:secomea-dev/recipes?dir=dev-tools/core"`
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

    # Globally installed .NET - if desired/needed
    # `nix profile install "github:secomea-dev/recipes?dir=dev-tools/dotnet"`
    # combinedDotNetSDKs

    # nix devShell (with direnv)
    # pkgs.corepack
    # pkgs.bun
    # pkgs.deno
    # pkgs.biome
    # pkgs.nodejs_latest
    # combinedDotNetSDKs
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      # ''${builtins.readFile ../../../shell/bash/PS1}
      ${builtins.readFile ../../../shell/bash/config}
      ${builtins.readFile ../../../shell/colours}

      ${builtins.readFile ../../../shell/common}

      export DOCKER_REGISTRY_HOSTNAME="$(cat ${config.sops.secrets.docker_registry_hostname.path})"
      export GITHUB_USER="$(cat ${config.sops.secrets.github_user.path})"
      export GITHUB_TOKEN="$(cat ${config.sops.secrets.github_token.path})"
      export GH_TOKEN="$(cat ${config.sops.secrets.gh_token.path})"
      export GITHUB_PAT="$GH_TOKEN"
      export GITHUB_REPO_PAT="$GITHUB_TOKEN"
      export NIX_CONFIG="access-tokens = github.com/secomea-dev=$GITHUB_TOKEN"

      alias mnotes='gocryptfs ~/Notes.encrypted ~/Notes'
      alias unotes='fusermount -u ~/Notes'
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
    HOME_CONFIGUTATION_CONTEXT = "work";
    # DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
}
