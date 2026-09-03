# Whole-process sandbox shared by Claude Code, Codex, and OpenCode. Native
# tools, plugins, MCP servers, and child processes all inherit this boundary.
{
  lib,
  pkgs,
  policy,
}: let
  common = import ./common.nix {
    inherit lib pkgs;
  };
  platform =
    import
    (
      if pkgs.stdenv.hostPlatform.isDarwin
      then ./darwin.nix
      else ./linux.nix
    )
    {
      inherit common lib pkgs policy;
    };
  mkRunner = agent: profile: platform.mkRunner agent profile;
  runners = lib.mapAttrs mkRunner policy.outerSandboxProfiles;

  wrapPackage = {
    agent,
    package,
    executable,
  }: let
    runner = runners.${agent};
  in
    pkgs.symlinkJoin {
      name = "${agent}-outer-sandboxed-${lib.getName package}";
      version = lib.getVersion package;
      paths = [package];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        rm -f "$out/bin/${executable}"
        makeWrapper ${runner}/bin/${agent}-outer-sandbox "$out/bin/${executable}" \
          --add-flags ${lib.escapeShellArg "${package}/bin/${executable}"}
      '';
    };
in {
  inherit wrapPackage;
}
