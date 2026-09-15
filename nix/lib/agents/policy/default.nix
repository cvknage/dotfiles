{
  lib,
  homeDirectory,
  xdgConfigHome,
  isDarwin,
  orderBefore ? (_: value: value),
  uid ? 1000,
  gitIdentityPublicKeyPath ? null,
  gitIdentityDirectory ? null,
}: let
  paths = import ./paths.nix {
    inherit
      gitIdentityDirectory
      gitIdentityPublicKeyPath
      homeDirectory
      isDarwin
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
    dockerProxySocketPath
    homeDirectory
    outerSandboxProfiles
    sshAgentSocket
    toolCachePaths
    workspaceRoots
    ;
  inherit claude codex opencode;
}
