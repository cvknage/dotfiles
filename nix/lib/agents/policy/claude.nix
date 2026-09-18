{
  paths,
  lib,
}: let
  commands = import ./commands.nix;
  inherit (paths) agentPaths claudeGlobalSettingsPaths claudeProjectSettingsPaths deniedPathPatterns;
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
          "WebFetch"
          "mcp__code-graph__*"
          "mcp__context7__*"
          "mcp__memory__*"
          "mcp__nixos__*"
          "mcp__sessions__*"
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
        deniedPathPatterns;
      additionalDirectories = agentPaths.claude.trustedRoots;
      disableBypassPermissionsMode = "disable";
    };

    sandbox.enabled = false;
  };
  mutableSettingsPath = agentPaths.claude.mutableSettingsPath;
}
