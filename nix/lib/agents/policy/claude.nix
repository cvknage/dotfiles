{
  paths,
  lib,
}: let
  commands = import ./commands.nix;
  inherit (paths) agentPaths claudeGlobalSettingsPaths claudeProjectSettingsPaths deniedPaths;
  expandCommandPrefixes = lib.concatMap (prefix: [prefix "${prefix} *"]);
  toClaudePath = path: "//${lib.removePrefix "/" path}";
  toClaudeBashRules = prefixes: map (pattern: "Bash(${pattern})") (expandCommandPrefixes prefixes);
  toClaudeEditRules = paths: map (path: "Edit(${toClaudePath path})") paths;
in {
  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    permissions = {
      allow =
        [
          "Bash(*)"
          "mcp__context7__*"
          "mcp__nixos__*"
        ]
        ++ lib.concatMap (path: [
          "Read(${toClaudePath path})"
          "Read(${toClaudePath path}/**)"
          "Edit(${toClaudePath path})"
          "Edit(${toClaudePath path}/**)"
        ])
        (agentPaths.claude.trustedRoots ++ agentPaths.claude.scratchRoots);
      ask = (toClaudeBashRules commands.ask) ++ (toClaudeEditRules claudeProjectSettingsPaths);
      deny =
        (toClaudeBashRules commands.deny)
        ++ (toClaudeEditRules claudeGlobalSettingsPaths)
        ++ lib.concatMap (path: [
          "Read(${toClaudePath path})"
          "Read(${toClaudePath path}/**)"
        ])
        deniedPaths;
      additionalDirectories = agentPaths.claude.trustedRoots;
      disableBypassPermissionsMode = "disable";
    };

    sandbox.enabled = false;
  };
  mutableSettingsPath = agentPaths.claude.mutableSettingsPath;
}
