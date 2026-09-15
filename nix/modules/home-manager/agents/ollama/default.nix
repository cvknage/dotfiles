# Shared ollama model ladder. claude derives its tier aliases from `tierModels`;
# codex builds its model catalog from `models`. Values verified per model against
# `ollama show`.
{
  config,
  homeContext,
  lib,
  ...
}: let
  # First entry is codex's default model; keep the opus tier there.
  models = [
    {
      tier = "opus";
      model = "glm-5.3-flash:cloud";
      context_window = 1048576;
      input_modalities = ["text" "image"];
    }
    {
      # The auto-mode safety classifier rides claude's sonnet alias, so this tier
      # wants a fast model.
      tier = "sonnet";
      model = "deepseek-v4.1-flash:cloud";
      context_window = 1048576;
      input_modalities = ["text"];
    }
    {
      tier = "fable";
      model = "kimi-k3:cloud";
      context_window = 1048576;
      input_modalities = ["text"];
    }
    {
      tier = "haiku";
      model = "nemotron-3-super:cloud";
      context_window = 262144;
      input_modalities = ["text"];
    }
  ];
in {
  # isPrivate, never !isWork: home-context.nix matches the context variable against
  # a literal, so a negative gate fails open and enables ollama for every context
  # that is not literally "work" - shared, unset, or any future role.
  enabled = homeContext.isPrivate config;

  inherit models;

  # [1m] is claude's own context-window label, stripped before the request, and
  # valid only at 1048576 tokens: it suppresses compaction, so a smaller model
  # would fail at the API instead.
  tierModels = lib.listToAttrs (map (m: {
      name = m.tier;
      value = "${m.model}${lib.optionalString (m.context_window >= 1048576) "[1m]"}";
    })
    models);

  # The model both agents start on: claude's /model Default resolves through the
  # opus alias, and codex marks the first catalog entry as its default.
  mainModel = (lib.findFirst (m: m.tier == "opus") (builtins.head models) models).model;
}
