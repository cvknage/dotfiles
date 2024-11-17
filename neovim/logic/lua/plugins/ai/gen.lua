-- Install Ollama: https://ollama.ai/download

return {
  "David-Kunz/gen.nvim",
  enabled = vim.fn.executable("ollama") == 1,
  opts = {
    model = "codellama:13b", -- The model to use.
    display_mode = "split",  -- The display mode. Can be "float" or "split".
    show_prompt = true,      -- Shows the Prompt submitted to Ollama.
    show_model = false,      -- Displays which model you are using at the beginning of your chat session.
    no_auto_close = false,   -- Never closes the window automatically.
    ---@diagnostic disable-next-line: unused-local
    init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end, -- Function to initialize Ollama
    command = "curl --silent --no-buffer -X POST http://localhost:11434/api/generate -d $body",
    -- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
    -- This can also be a lua function returning a command string, with options as the input parameter.
    -- The executed command must return a JSON object with { response, context }
    -- (context property is optional).
    list_models = "<omitted lua function>", -- Retrieves a list of model names
    debug = false                           -- Prints errors and the command which is run.
  },
  cmd = "Gen",
  keys = {
    { "<leader>ag", ":Gen<CR>", mode = { "n", "v" }, desc = "Gen" },
    { "<leader>ac", ":Gen Chat<CR>", mode = { "n", "v" }, desc = "Chat" },
    { "<leader>aq", ":Gen Ask<CR>", mode = { "n", "v" }, desc = "Ask Questoin" },
    { "<leader>ar", ":Gen Review_Code<CR>", mode = { "n", "v" }, desc = "Review Code" },
    { "<leader>aC", ":Gen Change_Code<CR>", mode = { "n", "v" }, desc = "Change Code" },
  },
}
