{
  lib,
  homeDirectory,
  xdgConfigHome,
  isDarwin,
  orderBefore ? (_: value: value),
  gitIdentityDirectory ? null,
}: let
  paths = import ./paths.nix {
    inherit
      gitIdentityDirectory
      homeDirectory
      isDarwin
      lib
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
    dockerDeniedPaths
    dockerProxySocketPath
    homeDirectory
    outerSandboxProfiles
    runtimeCredentialDirs
    sshAgentSocket
    toolCachePaths
    workspaceRoots
    ;
  inherit claude codex opencode;
}
