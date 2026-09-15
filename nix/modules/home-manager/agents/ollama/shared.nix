# Shared ollama model ladder and the private-context gate. claude derives its tier
# aliases from `models` and codex its model catalog; values verified per model
# against `ollama show`.
{
  config,
  homeContext,
  ...
}: {
  # isPrivate, never !isWork: home-context.nix matches the context variable against
  # a literal, so a negative gate fails open and enables ollama for every context
  # that is not literally "work" - shared, unset, or any future role.
  enabled = homeContext.isPrivate config;

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
}
