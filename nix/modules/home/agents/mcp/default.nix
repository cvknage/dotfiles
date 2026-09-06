{
  config,
  homeContext,
  lib,
  pkgs,
  ...
}: let
  # MCP servers inherit the agent's environment, so package managers inside
  # them reuse the agent's shared caches instead of a temp dir per server.
  mkMcpCmd = name: runtimeInputs: env: command:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      inherit runtimeInputs;
      text =
        lib.concatStrings
        (lib.mapAttrsToList (key: value: ''
            export ${key}=${value}
          '')
          env)
        + ''
          exec ${command} "$@"
        '';
    };
in {
  programs.mcp = {
    enable = true;
    servers = {
      # Durable agent knowledge, persisted to a local graph file.
      memory = {
        command = lib.getExe (mkMcpCmd "memory" [] {
          MEMORY_FILE_PATH = ''"$HOME/.local/state/agent-memory/graph.jsonl"'';
        } (lib.getExe pkgs.mcp-server-memory));
      };
      nixos = {
        command = lib.getExe (mkMcpCmd "nixos" [pkgs.nix] {
          NIX_REMOTE = "daemon";
        } "nix");
        args = ["run" "github:utensils/mcp-nixos" "--"];
      };
      context7 = {
        command = lib.getExe (mkMcpCmd "context7" [pkgs.nodejs] {} "npx");
        args = ["-y" "@upstash/context7-mcp"];
      };
      atlassian = lib.mkIf (homeContext.isWork config) {
        type = "local";
        command = lib.getExe (mkMcpCmd "atlassian" [pkgs.nodejs] {} "npx");
        args = ["-y" "mcp-remote" "https://mcp.atlassian.com/v1/mcp"];
      };
      /*
      kubernetes = lib.mkIf (homeContext.isWork config) {
        type = "local";
        command = lib.getExe (mkMcpCmd "kubernetes" [pkgs.nodejs] {} "npx");
        args = ["-y" "kubernetes-mcp-server@latest"];
      };
      */
      /*
      figma = lib.mkIf (homeContext.isWork config) {
        type = "remote";
        url = "https://mcp.figma.com/mcp";
      };
      */
      /*
      github = lib.mkIf (homeContext.isWork config) {
        type = "remote";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {
          Authorization = "Bearer {env:GITHUB_TOKEN}";
        };
      };
      */
      /*
      azure = lib.mkIf (homeContext.isWork config) {
        type = "local";
        command = lib.getExe (mkMcpCmd "azure" [pkgs.nodejs pkgs.azure-cli] {
          LD_LIBRARY_PATH = ''"${lib.makeLibraryPath [pkgs.icu]}:''${LD_LIBRARY_PATH:-}"'';
        } "npx");
        args = ["-y" "@azure/mcp@latest" "server" "start"];
        env = {
          AZURE_TOKEN_CREDENTIALS = "dev";
        };
      };
      */
    };
  };
}
