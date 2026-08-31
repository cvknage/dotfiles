# Install the policy at the root-owned configuration tier. Agents can edit the
# Nix source, but cannot make a policy change effective without a rebuild.
{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDirectory =
    if isDarwin
    then "/Users/${user}"
    else "/home/${user}";
  files = import ./managed-files.nix {
    inherit homeDirectory inputs lib pkgs;
  };
in {
  environment.etc =
    {"codex/requirements.toml".source = files.codex;}
    // lib.optionalAttrs (!isDarwin) {
      "claude-code/managed-settings.json".source = files.claude;
      "opencode/opencode.json".source = files.opencode;
    };

  # nix-darwin only splices known activation names into the generated script.
  system.activationScripts = lib.optionalAttrs isDarwin {
    postActivation.text = lib.mkAfter ''
      echo "installing managed agent policies..." >&2
      /bin/mkdir -p "/Library/Application Support/ClaudeCode"
      /bin/ln -sfn "${files.claude}" "/Library/Application Support/ClaudeCode/managed-settings.json"
      /bin/mkdir -p "/Library/Application Support/opencode"
      /bin/ln -sfn "${files.opencode}" "/Library/Application Support/opencode/opencode.json"
    '';
  };
}
