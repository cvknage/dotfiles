{
  config,
  homeContext,
  lib,
  pkgs,
  sandboxedPackage,
  ...
}: let
  ollama = import ./shared.nix {inherit config homeContext;};
  # [1m] is claude's own context-window label, stripped before the request, and
  # valid only at 1048576 tokens: it suppresses compaction, so a smaller model
  # would fail at the API.
  tierModels = lib.listToAttrs (map (m: {
      name = m.tier;
      value = "${m.model}${lib.optionalString (m.context_window >= 1048576) "[1m]"}";
    })
    ollama.models);
  # Only the secret's *path* reaches the wrapper; an interpolated value would land
  # world-readable in /nix/store.
  apiKeyPath =
    if (config.sops.secrets or {}) ? ollama_api_key
    then config.sops.secrets.ollama_api_key.path
    else "";
in {
  inherit (ollama) enabled;

  package = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # ANTHROPIC_AUTH_TOKEN, not ANTHROPIC_API_KEY: claude sends the former as
      # `Authorization: Bearer` (accepted), the latter as `x-api-key` (rejected).
      token_path=${lib.escapeShellArg apiKeyPath}
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

      export ANTHROPIC_DEFAULT_OPUS_MODEL="${tierModels.opus}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${tierModels.sonnet}"
      export ANTHROPIC_DEFAULT_FABLE_MODEL="${tierModels.fable}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${tierModels.haiku}"

      export CLAUDE_CODE_ATTRIBUTION_HEADER=0
      export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

      exec ${lib.escapeShellArg "${sandboxedPackage}/bin/claude"} "$@"
    '';
  };
}
