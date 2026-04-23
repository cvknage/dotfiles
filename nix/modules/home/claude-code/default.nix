{
  config,
  inputs,
  lib,
  pkgs,
  repoScopes,
  ...
}: let
  sharedPermissions = import ../agents/command-permissions.nix;
  permissionsLib = import ../agents/permissions-lib.nix {inherit lib;};

  scopedPathRules = permissionsLib.mkClaudeScopedPathRules repoScopes;

  fileAccessRules = lib.flatten (map (dir: [
      "Read(${dir}/**)"
      "Edit(${dir}/**)"
      "Write(${dir}/**)"
    ])
    repoScopes);

  hookScript = pkgs.writeShellApplication {
    name = "claude-code-deny-outside-repo-scopes";
    runtimeInputs = [pkgs.jq pkgs.python3];
    text =
      builtins.replaceStrings
      ["@repoScopes@"]
      [
        (lib.concatStringsSep "\n    " (map (scope: ''"${scope}"'') repoScopes))
      ]
      (builtins.readFile ./deny-outside-repo-scopes.sh);
  };

  # Persist Claude settings in a writable location so Claude Code can mutate
  # settings.json for plugin install/management.
  mutableSettingsPath = "${config.xdg.stateHome}/claude/settings.json";
  managedSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON settings);

  activationScript =
    builtins.replaceStrings
    ["@mutableSettingsPath@" "@managedSettingsFile@" "@coreutils@" "@jq@"]
    [mutableSettingsPath "${managedSettingsFile}" "${pkgs.coreutils}" "${pkgs.jq}"]
    (builtins.readFile ./materialize-settings.sh);

  claudeCodePackage = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

  permissions = {
    allow =
      (permissionsLib.mkClaudeBashPermissions sharedPermissions).allow
      ++ scopedPathRules
      ++ fileAccessRules;
    ask = (permissionsLib.mkClaudeBashPermissions sharedPermissions).ask;
    deny = (permissionsLib.mkClaudeBashPermissions sharedPermissions).deny;
    additionalDirectories = repoScopes;
  };

  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash|Read|Edit|Write";
          hooks = [
            {
              type = "command";
              command = "${hookScript}/bin/claude-code-deny-outside-repo-scopes";
            }
          ];
        }
      ];
    };
    inherit permissions;
  };
in {
  # Out-of-store symlink so Claude Code can update settings at runtime.
  home.file.".claude/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink mutableSettingsPath;
  };

  # Merge managed settings into the mutable state file on activation.
  # Nix-controlled keys (hooks, permissions) always win; user/plugin keys are preserved.
  home.activation.claudeCodeMaterializeSettings =
    lib.hm.dag.entryAfter ["writeBoundary"] activationScript;

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    package = claudeCodePackage;
    inherit settings;
  };
}
