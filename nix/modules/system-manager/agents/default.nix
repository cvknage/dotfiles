{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  homeDirectory = "/home/${user}";
  files = import ../../shared/agents/policy/managed-files.nix {
    inherit homeDirectory inputs lib pkgs;
  };
in {
  environment.etc = {
    "claude-code/managed-settings.json".source = files.claude;
    "opencode/opencode.json".source = files.opencode;
    "codex/requirements.toml".source = files.codex;
  };
}
