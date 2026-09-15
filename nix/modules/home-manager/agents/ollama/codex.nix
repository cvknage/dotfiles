{
  config,
  homeContext,
  lib,
  pkgs,
  sandboxedPackage,
  ...
}: let
  ollama = import ./shared.nix {inherit config homeContext lib;};

  # Without a catalog codex falls back to unknown-model metadata, which changes
  # the request shape it emits. Shape mirrors the file `ollama launch codex`
  # generates; experimental_supported_tools must stay empty, or codex sends
  # additional_tools input items that ollama's /v1/responses cannot parse.
  catalog = pkgs.writeText "codex-ollama-models.json" (builtins.toJSON {
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
in {
  inherit (ollama) enabled;

  # "ollama" is a reserved built-in provider id in codex; a custom one must not
  # collide with it.
  provider = lib.optionalAttrs ollama.enabled {
    model = ollama.mainModel;
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
    model_catalog_json = "${catalog}";
  };

  package = pkgs.writeShellApplication {
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

      exec ${lib.escapeShellArg "${sandboxedPackage}/bin/codex"} "$@"
    '';
  };
}
