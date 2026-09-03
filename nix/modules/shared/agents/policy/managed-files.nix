# Root-owned policy files shared by NixOS, nix-darwin, and standalone Home
# Manager installation.
{
  inputs,
  lib,
  pkgs,
  homeDirectory,
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  hmLib = inputs.home-manager.lib.hm;
  orderedJsonFormat = hmLib.generators.mkDAGOrderedJsonFormat {inherit pkgs;};
  policy = import ./default.nix {
    inherit isDarwin lib homeDirectory;
    xdgConfigHome = "${homeDirectory}/.config";
    orderBefore = hmLib.dag.entryBefore;
  };
in {
  # Lower tiers may add approvals or stricter rules; managed asks and denies
  # still take precedence, and the outer sandbox remains the hard boundary.
  claude = pkgs.writeText "claude-managed-settings.json" (builtins.toJSON policy.claude.settings);
  opencode = orderedJsonFormat.generate "opencode-managed-settings.json" policy.opencode.settings;
  codex = (pkgs.formats.toml {}).generate "codex-requirements.toml" policy.codex.requirements;
}
