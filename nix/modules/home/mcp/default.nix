{
  config,
  lib,
  pkgs,
  ...
}: let
  /*
  mkPythonCmd = name: command:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [
        pkgs.python3
        pkgs.uv
      ];
      text = ''
        exec ${command} "$@"
      '';
    };
  */
  mkNpxCmd = name:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.nodejs];
      text = ''
        exec npx "$@"
      '';
    };
  mkAzureCmd = name:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [
        pkgs.nodejs
        pkgs.azure-cli
      ];
      text = ''
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgs.icu]}:''${LD_LIBRARY_PATH:-}"
        exec npx "$@"
      '';
    };
  isWorkContext = config.home.sessionVariables.HOME_CONFIGURATION_CONTEXT == "work";
in {
  programs.mcp = {
    enable = true;
    servers = {
      filesystem = {
        type = "local";
        command = lib.getExe (mkNpxCmd "filesystem");
        args =
          ["-y" "@modelcontextprotocol/server-filesystem"]
          ++ [
            "${config.home.homeDirectory}/.dotfiles"
          ]
          ++ lib.optionals pkgs.stdenv.isDarwin [
            "${config.home.homeDirectory}/Code"
          ]
          ++ lib.optionals (!pkgs.stdenv.isDarwin) [
            "${config.home.homeDirectory}/code"
          ];
      };
      nixos = {
        type = "local";
        command = "nix";
        args = ["run" "github:utensils/mcp-nixos" "--"];
      };
      context7 = {
        type = "local";
        command = lib.getExe (mkNpxCmd "context7");
        args = ["-y" "@upstash/context7-mcp"];
      };
      github = lib.mkIf isWorkContext {
        type = "remote";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {
          Authorization = "Bearer {env:GITHUB_MCP_TOKEN}";
        };
      };
      kubernetes = lib.mkIf isWorkContext {
        type = "local";
        command = lib.getExe (mkNpxCmd "kubernetes");
        args = ["-y" "kubernetes-mcp-server@latest"];
      };
      azure = lib.mkIf isWorkContext {
        type = "local";
        command = lib.getExe (mkAzureCmd "azure");
        args = ["-y" "@azure/mcp@latest" "server" "start"];
        env = {
          AZURE_TOKEN_CREDENTIALS = "dev";
        };
      };
    };
  };
}
