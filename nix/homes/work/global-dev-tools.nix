{pkgs, ...}:
/*
let
combinedDotNetSDKs = pkgs.buildEnv {
  name = "combinedDotNetSDKs";
  paths = [
    (
      with pkgs.dotnetCorePackages;
        combinePackages [
          sdk_10_0
        ]
    )
  ];
};
in
*/
{
  imports = [];

  home.packages = [
    # Git Tools
    pkgs.gh
    # pkgs.gh-stack

    # Azure Tools
    pkgs.azure-cli
    pkgs.bicep

    # Kubernetes Tools
    pkgs.kubelogin
    pkgs.kubectl
    pkgs.kind
    pkgs.kubernetes-helm
    pkgs.k9s
    pkgs.pluto
    pkgs.mirrord

    # Developer Tools
    # pkgs.go-task

    # SDKs
    pkgs.python3
    # combinedDotNetSDKs

    # Test Tools
    pkgs.k6

    # Other CLI Tools
    # pkgs.jq

    # JS/TS Tools
    # pkgs.corepack
    # pkgs.bun
    # pkgs.deno
    # pkgs.biome
    # pkgs.nodejs_latest
  ];

  /*
  home.sessionVariables = {
    DOTNET_ROOT = "${combinedDotNetSDKs}/share/dotnet/";
  };
  */
}
