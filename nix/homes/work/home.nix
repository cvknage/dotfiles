{ inputs, config, pkgs, user, ... }:

let
  # Create combined package of dotnet SDKs
  combinedDotNetSDKs = pkgs.buildEnv {
    name = "combinedDotNetSDKs";
    paths = [
      (with pkgs.dotnetCorePackages;
        combinePackages [
          sdk_9_0
          sdk_7_0
        ]
      )
    ];
  };
in

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
    # Office Tools
    pkgs.slack
    pkgs.teams-for-linux
    pkgs.buttercup-desktop

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

    # SDKs
    combinedDotNetSDKs
    pkgs.python3

    # gcc & make needed for nvim to install tresitter and fzf-native
    pkgs.gcc
    pkgs.gnumake
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      ${builtins.readFile ../../../shell/bash/PS1}
    '';
    profileExtra = ''
      ${builtins.readFile ../../../shell/common}

      CUSTOM_VARIABLES="$HOME/.custom-variables"
      if [ -f "$CUSTOM_VARIABLES" ]; then
        . "$CUSTOM_VARIABLES"
      fi

      if command -v gh > /dev/null; then
        function gh-workflow() {
          local solution=''${1:-$(pwd | awk -F'solutions/' '{print $2}' | cut -d'/' -f1 | sed 's/^$/nothing/')}
          gh workflow run build-deploy-staging.yml --ref $(git branch --show-current) --field solution=$solution
        }
        alias ghwf="gh-workflow"
      fi
    '';
    shellAliases = {
      vim = "nvim";
    };
  };

  programs.firefox.enable = true;

  home.sessionVariables = {
    DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
}
