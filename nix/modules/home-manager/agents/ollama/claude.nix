{
  config,
  homeContext,
  lib,
  pkgs,
  sandboxedPackage,
  ...
}: let
  ollama = import ./default.nix {inherit config homeContext lib;};
  # Only the secret's *path* reaches the wrapper; a value interpolated here
  # would land world-readable in /nix/store.
  apiKeyPath =
    if (config.sops.secrets or {}) ? ollama_api_key
    then config.sops.secrets.ollama_api_key.path
    else "";
in {
  inherit (ollama) enabled;

  package = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # Direct to ollama.com. ANTHROPIC_AUTH_TOKEN, not ANTHROPIC_API_KEY:
      # claude sends the former as `Authorization: Bearer` (accepted) and the
      # latter as `x-api-key` (rejected).
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

      export ANTHROPIC_DEFAULT_OPUS_MODEL="${ollama.tierModels.opus}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${ollama.tierModels.sonnet}"
      export ANTHROPIC_DEFAULT_FABLE_MODEL="${ollama.tierModels.fable}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ollama.tierModels.haiku}"

      export CLAUDE_CODE_ATTRIBUTION_HEADER=0
      export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

      exec ${lib.escapeShellArg "${sandboxedPackage}/bin/claude"} "$@"
    '';
  };
}
