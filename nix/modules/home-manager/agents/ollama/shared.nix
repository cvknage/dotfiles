# Model ladder; values verified per model against `ollama show`.
{
  config,
  homeContext,
  ...
}: {
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
      # The auto-mode safety classifier rides claude's sonnet alias: keep this tier fast.
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
