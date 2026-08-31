{
  config,
  lib,
  pkgs,
  ...
}: let
  policy = import ../../agents/policy.nix {
    inherit lib;
    homeDirectory = config.home.homeDirectory;
    xdgConfigHome = config.xdg.configHome;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    orderBefore = lib.hm.dag.entryBefore;
  };
  sandbox = import ../../agents/outer-sandbox.nix {
    inherit lib pkgs policy;
  };
in {
  _module.args.agentPolicy = policy;
  _module.args.agentSandbox = sandbox;

  imports = [
    ../mcp
    ../claude-code
    ../codex
    ../opencode
  ];
}
