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
  # The daemon runs the web_search loop that ollama.com's hosted endpoint does not,
  # so claude talks to the daemon rather than the cloud.
  ollamaUrl = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
in {
  inherit (ollama) enabled;

  package = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # Check only - starting or killing the daemon here reintroduces the ownership race.
      if ! ${pkgs.curl}/bin/curl -fsS --max-time 2 ${lib.escapeShellArg "${ollamaUrl}/api/version"} >/dev/null 2>&1; then
        echo "claude: nothing listening on ${ollamaUrl}; is the services.ollama agent running?" >&2
      fi

      # The daemon brokers the credential upstream; claude still requires the variable.
      export ANTHROPIC_AUTH_TOKEN="ollama"
      export ANTHROPIC_API_KEY=""

      export ANTHROPIC_BASE_URL=${lib.escapeShellArg ollamaUrl}

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
