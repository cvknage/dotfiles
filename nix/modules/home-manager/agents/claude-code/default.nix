{
  agentPolicy,
  agentSandbox,
  config,
  homeContext,
  inputs,
  lib,
  pkgs,
  ...
}: let
  claudeCodePackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  codeGraphHooks = import ../hooks;

  claudePaceStatusline = pkgs.runCommand "claude-pace-statusline" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    install -Dm755 ${inputs.claude-pace}/claude-pace.sh $out/bin/claude-pace-statusline
    wrapProgram $out/bin/claude-pace-statusline \
      --prefix PATH : ${lib.makeBinPath [pkgs.jq pkgs.git pkgs.coreutils]}
  '';
  sandboxedClaudeCode = agentSandbox.wrapPackage {
    agent = "claude";
    package = claudeCodePackage;
    executable = "claude";
  };

  ollama = import ../ollama.nix {inherit config homeContext lib;};
  # Only the secret's *path* reaches the wrapper; a value interpolated here
  # would land world-readable in /nix/store.
  ollamaApiKeyPath =
    if (config.sops.secrets or {}) ? ollama_api_key
    then config.sops.secrets.ollama_api_key.path
    else "";
  ollamaDirectClaudeCode = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # Direct to ollama.com. ANTHROPIC_AUTH_TOKEN, not ANTHROPIC_API_KEY:
      # claude sends the former as `Authorization: Bearer` (accepted) and the
      # latter as `x-api-key` (rejected).
      token_path=${lib.escapeShellArg ollamaApiKeyPath}
      if [ -n "$token_path" ]; then
        if [ -r "$token_path" ]; then
          ANTHROPIC_AUTH_TOKEN="$(cat "$token_path")"
          export ANTHROPIC_AUTH_TOKEN
        else
          echo "claude: ollama API key unreadable at $token_path" >&2
        fi
      fi

      export ANTHROPIC_BASE_URL="https://ollama.com"
      export ANTHROPIC_API_KEY=""

      export ANTHROPIC_DEFAULT_OPUS_MODEL="${ollama.tierModels.opus}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${ollama.tierModels.sonnet}"
      export ANTHROPIC_DEFAULT_FABLE_MODEL="${ollama.tierModels.fable}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ollama.tierModels.haiku}"

      export CLAUDE_CODE_ATTRIBUTION_HEADER=0
      export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

      exec ${lib.escapeShellArg "${sandboxedClaudeCode}/bin/claude"} "$@"
    '';
  };

  # Persist Claude settings in a writable location so Claude Code can mutate
  # settings.json for plugin install/management.
  mutableSettingsPath = agentPolicy.claude.mutableSettingsPath;
  managedSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON settings);
  materialize = import ../materialize-config.nix {inherit lib pkgs;};

  # Claude stores user-scoped MCP servers in ~/.claude/.config.json. Home Manager's
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

  mcpActivationScript = ''
    state_file="$HOME/.claude/.config.json"
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

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
    ${pkgs.coreutils}/bin/install -m 0600 "$out_config" "$state_file"
    ${pkgs.coreutils}/bin/rm -rf "$tmp_dir"
    trap - EXIT
  '';

  settings =
    agentPolicy.claude.settings
    // {
      statusLine = {
        type = "command";
        command = "${claudePaceStatusline}/bin/claude-pace-statusline";
      };
      hooks.PostToolUse = [
        {
          matcher = "Edit|Write|NotebookEdit";
          hooks = [
            {
              type = "command";
              command = codeGraphHooks.reindexCommand;
            }
          ];
        }
      ];
    };
in {
  # Merge managed settings into the mutable state file on activation.
  # Nix-controlled hooks, permissions, and sandbox keys always win; other user/plugin keys are preserved.
  home.activation.claudeCodeMaterializeSettings = materialize.mkActivation {
    format = "json";
    statePath = mutableSettingsPath;
    linkPath = "${config.home.homeDirectory}/.claude/settings.json";
    managedFile = managedSettingsFile;
    authoritativeKeys = [
      "hooks"
      "permissions"
      "sandbox"
    ];
  };

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
    package =
      if ollama.enabled
      then ollamaDirectClaudeCode
      else sandboxedClaudeCode;
  };
}
