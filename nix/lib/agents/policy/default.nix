{
  lib,
  homeDirectory,
  xdgConfigHome,
  isDarwin,
  isWork ? false,
  orderBefore ? (_: value: value),
  uid ? 1000,
}: let
  paths = import ./paths.nix {
    inherit
      homeDirectory
      isDarwin
      isWork
      lib
      uid
      xdgConfigHome
      ;
  };
  claude = import ./claude.nix {inherit lib paths;};
  codex = import ./codex.nix {inherit lib paths;};
  opencode = import ./opencode.nix {inherit lib orderBefore paths;};
in {
  inherit
    (paths)
    deniedPaths
    homeDirectory
    outerSandboxProfiles
    sshAgentSocket
    toolCachePaths
    workspaceRoots
    ;
  inherit claude codex opencode;
}
