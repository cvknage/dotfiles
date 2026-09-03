{
  config,
  homeContext,
  lib,
  pkgs,
  ...
}: let
  policy = import ../../shared/agents/policy/default.nix {
    inherit lib;
    homeDirectory = config.home.homeDirectory;
    xdgConfigHome = config.xdg.configHome;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    isWork = homeContext.isWork config;
    orderBefore = lib.hm.dag.entryBefore;
  };
  sandbox = import ./sandbox/default.nix {
    inherit lib pkgs policy;
  };
in {
  _module.args.agentPolicy = policy;
  _module.args.agentSandbox = sandbox;

  imports = [
    ./claude-code
    ./codex
    ./mcp
    ./opencode
  ];
}
