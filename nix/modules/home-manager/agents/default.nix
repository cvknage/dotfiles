{
  config,
  lib,
  options,
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

  # Both sandbox denylists resolve the secrets location from this default: the darwin Seatbelt
  # profile denies "$(getconf DARWIN_USER_TEMP_DIR)/secrets.d" and paths.nix denies
  # /run/user/<uid>/secrets.d for linux. Each encodes the "%r" substitution, so any other value
  # moves the secrets out from under every deny -- silently, since nothing else would fail.
  assertions = lib.optional (lib.hasAttrByPath ["sops" "defaultSecretsMountPoint"] options) {
    assertion = config.sops.defaultSecretsMountPoint == "%r/secrets.d";
    message = ''
      sops.defaultSecretsMountPoint is "${config.sops.defaultSecretsMountPoint}", but the
      agent sandbox denylists assume the default "%r/secrets.d", so decrypted secrets would
      land outside every deny. Update the deny in
      nix/modules/home-manager/agents/sandbox/darwin.nix (and paths.nix on linux) to match.
    '';
  };

  imports = [
    ./claude-code
    ./codex
    ./mcp
    ./opencode
    ./skills
  ];
}
