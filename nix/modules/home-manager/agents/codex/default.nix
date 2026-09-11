{
  agentPolicy,
  agentSandbox,
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  codexCliPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  codeGraphHooks = import ../hooks;
  sandboxedCodexCli = agentSandbox.wrapPackage {
    agent = "codex";
    package = codexCliPackage;
    executable = "codex";
  };

  materialize = import ../materialize-config.nix {inherit lib pkgs;};

  settingsFormat = pkgs.formats.toml {};
  xdgConfigHome = lib.removePrefix config.home.homeDirectory config.xdg.configHome;
  configDir =
    if config.home.preferXdgDirectories
    then "${xdgConfigHome}/codex"
    else ".codex";
  mutableConfigPath = agentPolicy.codex.mutableConfigPath;
  linkPath = "${config.home.homeDirectory}/${configDir}/config.toml";

  mcpServers =
    lib.mapAttrs (
      _: server:
      # TOML has no null; strip null-valued attrs (e.g. unset `url`/`enabled`)
      # that the mcp module leaves in place, or serialization fails with
      # "unsupported unit type".
        lib.filterAttrs (_: v: v != null) (
          (lib.removeAttrs server [
            "disabled"
            "headers"
          ])
          # Codex rejects http_headers on stdio servers, even when empty, and the
          # mcp module defaults `headers` to {} for every server.
          // (lib.optionalAttrs
            (!(server ? http_headers)
              && (server.headers or null) != null
              && server.headers != {}) {
              http_headers = server.headers;
            })
          // {
            enabled = !(server.disabled or false);
            default_tools_approval_mode = "approve";
          }
        )
    )
    config.programs.mcp.servers;

  settings =
    agentPolicy.codex.settings
    // {
      features.child_agents_md = true;
      suppress_unstable_features_warning = true;
      # ollama's per-launch config layer wipes codex's hooks.state trust on
      # every launch; baking the content-hash here keeps the reindex hook
      # trusted. Recapture the hash from a trusted session when the hook
      # definition changes.
      hooks.state."${config.home.homeDirectory}/${configDir}/hooks.json:post_tool_use:0:0".trusted_hash = "sha256:655cfe92116fd6fb09b6f8dec597169d9100c8d80f5b9fa07473830674ca491b";
    }
    // lib.optionalAttrs config.programs.mcp.enable {
      mcp_servers = mcpServers;
    };

  managedSettingsFile = settingsFormat.generate "codex-managed-config" settings;
in {
  home.activation.codexMaterializeConfig =
    lib.hm.dag.entryAfter ["writeBoundary"]
    (materialize.materializeConfig {
      format = "toml";
      managedFile = managedSettingsFile;
      statePath = mutableConfigPath;
      linkPath = linkPath;
      authoritativeKeys = [
        "approval_policy"
        "default_permissions"
        "mcp_servers"
        "permissions"
        "sandbox_mode"
        "sandbox_workspace_write"
      ];
    });

  programs.codex = {
    enable = true;
    package = sandboxedCodexCli;
    rules = {
      "shared-bash-permissions" = agentPolicy.codex.rules;
    };
    # NOTE: settings are intentionally NOT passed here — the module would write
    # config.toml as a Home Manager-managed file, colliding with the mutable
    # link the activation above owns.
    hooks.PostToolUse = [
      {
        hooks = [
          {
            type = "command";
            command = codeGraphHooks.reindexCommand;
          }
        ];
      }
    ];
  };
}
