# Consumed by claude (tier aliases, where `context_window` decides the [1m]
# tag: 1M-class only, since the tag suppresses compaction and a smaller model
# would fail at the API) and by codex (model catalog). Values verified per
# model against `ollama show`.
#
# First entry is codex's default model; keep the opus tier there.
[
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
]
