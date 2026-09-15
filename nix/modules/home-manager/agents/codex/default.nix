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
  codexCliPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  codeGraphHooks = import ../hooks;
  sandboxedCodexCli = agentSandbox.wrapPackage {
    agent = "codex";
    package = codexCliPackage;
    executable = "codex";
  };

  ollamaCodexCli = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      # The daemon attaches the cloud credential upstream, so the agent needs
      # no key of its own; codex still requires the variable to be set.
      export OLLAMA_API_KEY="ollama"

      # Check only; starting or killing the daemon here reintroduces the race
      # launchd exists to remove.
      if ! ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
        echo "codex: nothing listening on 127.0.0.1:11434; is the services.ollama agent running?" >&2
      fi

      exec ${lib.escapeShellArg "${sandboxedCodexCli}/bin/codex"} "$@"
    '';
  };
  ollama = import ../ollama.nix {inherit config homeContext lib;};
  # Without a catalog codex falls back to unknown-model metadata, which changes
  # the request shape it emits. Shape mirrors the file `ollama launch codex`
  # generates; experimental_supported_tools must stay empty, or codex sends
  # additional_tools input items that ollama's /v1/responses cannot parse.
  ollamaModelCatalog = pkgs.writeText "codex-ollama-models.json" (builtins.toJSON {
    models =
      map (m: {
        base_instructions = "";
        context_window = m.context_window;
        default_verbosity = "low";
        display_name = m.model;
        experimental_supported_tools = [];
        input_modalities = m.input_modalities;
        priority = 0;
        shell_type = "default";
        slug = m.model;
        support_verbosity = true;
        supported_in_api = true;
        # Each entry is a ReasoningEffortPreset {effort, description}; without
        # levels codex shows effort "none" and never asks the model to think.
        # "minimal" is not a level in codex 0.153.4.
        supported_reasoning_levels = [
          {
            effort = "low";
            description = "Fast responses with lighter reasoning";
          }
          {
            effort = "medium";
            description = "Balances speed and reasoning depth for everyday tasks";
          }
          {
            effort = "high";
            description = "Greater reasoning depth for complex problems";
          }
          {
            effort = "xhigh";
            description = "Extra high reasoning depth for complex problems";
          }
        ];
        default_reasoning_level = "medium";
        supports_parallel_tool_calls = false;
        supports_reasoning_summaries = false;
        truncation_policy = {
          limit = 10000;
          mode = "tokens";
        };
        visibility = "list";
      })
      ollama.models;
  });
  ollamaProvider = lib.optionalAttrs ollama.enabled {
    model = ollama.mainModel;
    # "ollama" is a reserved built-in provider id in codex; a custom one must
    # not collide with it.
    model_provider = "ollama-cloud";
    model_providers = {
      "ollama-cloud" = {
        name = "Ollama";
        # ollama.com refuses /v1/responses requests carrying codex's web_search tool.
        base_url = "http://127.0.0.1:11434/v1/";
        env_key = "OLLAMA_API_KEY";
        # Codex rejects the "chat" wire API at config load; ollama has served
        # /v1/responses since v0.13.3.
        wire_api = "responses";
      };
    };
    model_catalog_json = "${ollamaModelCatalog}";
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
      # Baking the content-hash keeps the reindex hook trusted without a
      # re-approval prompt; recapture it from a trusted session when the hook
      # definition changes.
      hooks.state."${config.home.homeDirectory}/${configDir}/hooks.json:post_tool_use:0:0".trusted_hash = "sha256:655cfe92116fd6fb09b6f8dec597169d9100c8d80f5b9fa07473830674ca491b";
    }
    // lib.optionalAttrs config.programs.mcp.enable {
      mcp_servers = mcpServers;
    }
    // ollamaProvider;

  managedSettingsFile = settingsFormat.generate "codex-managed-config" settings;
in {
  home.activation.codexMaterializeConfig =
    lib.hm.dag.entryAfter ["writeBoundary"]
    (materialize.materializeConfig {
      format = "toml";
      managedFile = managedSettingsFile;
      statePath = mutableConfigPath;
      linkPath = linkPath;
      # model is a seed: codex's own /model choice survives activation.
      defaultKeys = ["model"];
      authoritativeKeys = [
        "approval_policy"
        "default_permissions"
        "mcp_servers"
        "model_provider"
        "model_providers"
        "permissions"
        "sandbox_mode"
        "sandbox_workspace_write"
      ];
    });

  programs.codex = {
    enable = true;
    package =
      if ollama.enabled
      then ollamaCodexCli
      else sandboxedCodexCli;
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
