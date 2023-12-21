-- Configuration instructions: https://github.com/huggingface/llm.nvim#configuration
-- Install huggingface-cli: https://huggingface.co/docs/huggingface_hub/quick-start#installation

return {
  "huggingface/llm.nvim",
  build = "huggingface-cli login",
  opts = {
    tokens_to_clear = { "<EOT>" },
    fim = {
      enabled = true,
      prefix = "<PRE> ",
      middle = " <MID>",
      suffix = " <SUF>",
    },
    --[[
      -- Setting the model to a href, does not currently work with ollama:
      -- https://github.com/huggingface/llm-vscode/issues/60
      -- https://github.com/huggingface/llm-ls#roadmap
      model = "http://localhost:11434/api/generate",
    --]]
    model = "codellama/CodeLlama-13b-hf",
    context_window = 4096,
    tokenizer = {
      repository = "codellama/CodeLlama-13b-hf",
    },
    accept_keymap = "<C-y>",
    dismiss_keymap = "<C-e>",
  },
  event = "BufEnter",
}
