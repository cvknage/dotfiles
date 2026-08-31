{
  agentPolicy,
  agentSandbox,
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  claudeCodePackage = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  sandboxedClaudeCode = agentSandbox.wrapPackage {
    agent = "claude";
    package = claudeCodePackage;
    executable = "claude";
  };

  # Persist Claude settings in a writable location so Claude Code can mutate
  # settings.json for plugin install/management.
  mutableSettingsPath = agentPolicy.claude.mutableSettingsPath;
  managedSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON settings);

  # Claude stores user-scoped MCP servers in ~/.claude.json. Home Manager's
  # generic Claude integration currently materializes them as a plugin below
  # ~/.claude/skills, but Claude does not register that directory as an enabled
  # plugin. Merge the shared servers into Claude's actual user registry instead.
  # Claude already supplies its own hosted Context7 integration, so omit the
  # duplicate local server here while keeping it available to other agents.
  claudeSharedMcpServers = builtins.removeAttrs config.programs.mcp.servers ["context7"];
  claudeMcpServers = lib.mapAttrs (
    name: server:
      lib.hm.mcp.transformMcpServer {
        inherit server;
        exclude = ["enabled"];
        extraTransforms = [
          (value:
            value
            // {
              type =
                if (value.url or null) != null
                then "http"
                else "stdio";
            })
          (lib.hm.mcp.wrapEnvFilesCommand {inherit pkgs name;})
        ];
      }
  ) (lib.filterAttrs (_: server: (server.enabled or null) != false && (server.disabled or false) != true) claudeSharedMcpServers);
  managedMcpFile = pkgs.writeText "claude-code-managed-mcp.json" (builtins.toJSON {
    mcpServers = claudeMcpServers;
  });

  activationScript =
    builtins.replaceStrings
    ["@mutableSettingsPath@" "@managedSettingsFile@" "@coreutils@" "@jq@"]
    [mutableSettingsPath "${managedSettingsFile}" "${pkgs.coreutils}" "${pkgs.jq}"]
    (builtins.readFile ./materialize-settings.sh);

  mcpActivationScript = ''
    state_file="$HOME/.claude.json"
    managed_file=${lib.escapeShellArg "${managedMcpFile}"}

    tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap "${pkgs.coreutils}/bin/rm -rf '$tmp_dir'" EXIT

    user_config="$tmp_dir/user.json"
    out_config="$tmp_dir/out.json"

    if [ -e "$state_file" ]; then
      ${pkgs.coreutils}/bin/cp "$state_file" "$user_config"
    else
      ${pkgs.coreutils}/bin/printf '{}\n' > "$user_config"
    fi

    if ! ${pkgs.jq}/bin/jq -e 'type == "object"' "$user_config" >/dev/null 2>&1; then
      echo "Claude MCP activation: refusing to replace invalid $state_file" >&2
      exit 1
    fi

    ${pkgs.jq}/bin/jq -s '
      .[0] as $user
      | .[1] as $managed
      | ($user | del(.mcpServers)) * {mcpServers: ($managed.mcpServers // {})}
    ' "$user_config" "$managed_file" > "$out_config"

    ${pkgs.coreutils}/bin/install -m 0600 "$out_config" "$state_file"
    ${pkgs.coreutils}/bin/rm -rf "$tmp_dir"
    trap - EXIT
  '';

  settings = agentPolicy.claude.settings;
in {
  # Out-of-store symlink so Claude Code can update settings at runtime.
  home.file.".claude/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink mutableSettingsPath;
  };

  # Merge managed settings into the mutable state file on activation.
  # Nix-controlled hooks, permissions, and sandbox keys always win; other user/plugin keys are preserved.
  home.activation.claudeCodeMaterializeSettings =
    lib.hm.dag.entryAfter ["writeBoundary"] activationScript;

  # Nix owns the user-scoped MCP server set. Claude's plugin configuration is
  # stored separately, so runtime plugin installation remains unaffected.
  home.activation.claudeCodeMaterializeMcp =
    lib.hm.dag.entryAfter ["claudeCodeMaterializeSettings"] mcpActivationScript;

  # NOTE: settings are intentionally NOT passed to programs.claude-code here.
  # The module would write configDir/settings.json (~/.claude/settings.json),
  # colliding with the out-of-store symlink defined above. Instead the managed
  # `settings` are merged into the mutable state file by the activation script,
  # and the symlink points Claude Code at that writable copy.
  programs.claude-code = {
    enable = true;
    # MCP integration is materialized above in Claude's supported user scope.
    enableMcpIntegration = false;
    package = sandboxedClaudeCode;
  };
}
