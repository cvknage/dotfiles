{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  homeDirectory = "/Users/${user}";
  files = import ../../shared/agents/policy/managed-files.nix {
    inherit homeDirectory inputs lib pkgs;
  };
in {
  environment.etc."codex/requirements.toml".source = files.codex;

  # nix-darwin only splices known activation names into the generated script.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "installing managed agent policies..." >&2
    /bin/mkdir -p "/Library/Application Support/ClaudeCode"
    /bin/ln -sfn "${files.claude}" "/Library/Application Support/ClaudeCode/managed-settings.json"
    /bin/mkdir -p "/Library/Application Support/opencode"
    /bin/ln -sfn "${files.opencode}" "/Library/Application Support/opencode/opencode.json"
  '';
}
