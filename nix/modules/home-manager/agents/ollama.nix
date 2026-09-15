{
  config,
  homeContext,
  lib,
  ...
}: let
  models = import ./ollama-models.nix;
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
