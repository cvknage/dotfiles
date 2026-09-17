{
  config,
  lib,
  pkgs,
  ...
}: let
  policy = import ../../../lib/agents/policy/default.nix {
    inherit lib;
    homeDirectory = config.home.homeDirectory;
    xdgConfigHome = config.xdg.configHome;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    orderBefore = lib.hm.dag.entryBefore;
    gitIdentityDirectory =
      if config.preferences.gitIdentity.enable
      then config.preferences.gitIdentity.directory
      else null;
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
    ./skills
  ];
}
