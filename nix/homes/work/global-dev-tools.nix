{pkgs, ...}: let
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
  imports = [];

  home.packages = [
    pkgs.azure-cli
    pkgs.kubelogin
    pkgs.kubectl
    pkgs.kind
    pkgs.kubernetes-helm
    pkgs.go-task
    pkgs.k9s
    pkgs.pluto
    pkgs.mirrord
    pkgs.gh
    pkgs.k6
    pkgs.python3

    combinedDotNetSDKs

    pkgs.corepack
    pkgs.bun
    pkgs.deno
    pkgs.biome
    pkgs.nodejs_latest
  ];

  home.sessionVariables = {
    DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
}
