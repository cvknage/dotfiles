{
  config,
  lib,
  pkgs,
  ...
}: let
  mcpRuntimeDeps = [
    pkgs.nodejs
    # pkgs.uv
    # pkgs.python3
  ];
  mkMcpWrapper = name: command:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = mcpRuntimeDeps;
      text = ''
        exec ${command} "$@"
      '';
    };
  icuLibraryPath = lib.makeLibraryPath [pkgs.icu];
  mkMcpWrapperWithIcu = name: command:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = mcpRuntimeDeps;
      text = ''
        export LD_LIBRARY_PATH="${icuLibraryPath}:''${LD_LIBRARY_PATH:-}"
        exec ${command} "$@"
      '';
    };
  mcpContext7 = mkMcpWrapper "context7" "npx";
  mcpKubernetes = mkMcpWrapper "kubernetes" "npx";
  mcpFilesystem = mkMcpWrapper "filesystem" "npx";
  mcpAzure = mkMcpWrapperWithIcu "azure-mcp" "npx";
  filesystemRoots =
    [
      "${config.home.homeDirectory}/.dotfiles"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/Code"
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      "${config.home.homeDirectory}/code"
    ];
in {
  programs.mcp = {
    enable = true;
    servers = {
      github = {
        type = "https";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {
          Authorization = "Bearer {env:GITHUB_MCP_TOKEN}";
        };
      };
      context7 = {
        command = "${mcpContext7}/bin/mcp-context7";
        args = ["-y" "@upstash/context7-mcp"];
      };
      kubernetes = {
        command = "${mcpKubernetes}/bin/mcp-kubernetes";
        args = ["-y" "kubernetes-mcp-server@latest"];
      };
      filesystem = {
        command = "${mcpFilesystem}/bin/mcp-filesystem";
        args =
          ["-y" "@modelcontextprotocol/server-filesystem"]
          ++ filesystemRoots;
      };
      azure-mcp = {
        command = "${mcpAzure}/bin/mcp-azure-mcp";
        args = ["-y" "@azure/mcp@latest" "server" "start"];
        env = {
          AZURE_TOKEN_CREDENTIALS = "dev";
        };
      };
    };
  };
}
