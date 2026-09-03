{
  config,
  homeContext,
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
  # Agent launchers provide the shared writable tool caches. MCP wrappers
  # inherit those paths instead of replacing them with per-process temp caches.
  mkNpxCmd = name:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.nodejs];
      text = ''
        exec npx "$@"
      '';
    };
  mkNixCmd = name:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.nix];
      text = ''
        export NIX_REMOTE=daemon
        exec nix "$@"
      '';
    };
  /*
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
  */
in {
  programs.mcp = {
    enable = true;
    servers = {
      nixos = {
        command = lib.getExe (mkNixCmd "nixos");
        args = ["run" "github:utensils/mcp-nixos" "--"];
      };
      context7 = {
        command = lib.getExe (mkNpxCmd "context7");
        args = ["-y" "@upstash/context7-mcp"];
      };
      # kubernetes = lib.mkIf (homeContext.isWork config) {
      #   type = "local";
      #   command = lib.getExe (mkNpxCmd "kubernetes");
      #   args = ["-y" "kubernetes-mcp-server@latest"];
      # };
      # figma = lib.mkIf isWorkContext {
      #   type = "remote";
      #   url = "https://mcp.figma.com/mcp";
      # };
      # github = lib.mkIf isWorkContext {
      #   type = "remote";
      #   url = "https://api.githubcopilot.com/mcp/";
      #   headers = {
      #     Authorization = "Bearer {env:GITHUB_TOKEN}";
      #   };
      # };
      # azure = lib.mkIf isWorkContext {
      #   type = "local";
      #   command = lib.getExe (mkAzureCmd "azure");
      #   args = ["-y" "@azure/mcp@latest" "server" "start"];
      #   env = {
      #     AZURE_TOKEN_CREDENTIALS = "dev";
      #   };
      # };
      atlassian = lib.mkIf (homeContext.isWork config) {
        type = "local";
        command = lib.getExe (mkNpxCmd "atlassian");
        args = ["-y" "mcp-remote" "https://mcp.atlassian.com/v1/mcp"];
      };
    };
  };
}
