return {
  {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    -- nvim-treesitter is declared upstream, but only for parser installation, which
    -- tree-sitter-manager.nvim already handles. See the parser table at the bottom of this file.
    dependencies = {
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Actions" },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Chat Toggle" },
      { "<leader>ad", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add Selection to Chat" },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "Inline Prompt" },
    },
    ---@module 'codecompanion'
    ---@type CodeCompanion.Config
    opts = {
      interactions = {
        chat = { adapter = "claude_code" },
        inline = { adapter = "claude_code" },
      },
      adapters = {
        acp = {
          -- Spawns the "claude-agent-acp" binary from neovimExtraPackages.
          -- Auth falls back to CLAUDE_CODE_OAUTH_TOKEN, see "claude setup-token".
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              defaults = { timeout = 60000 },
            })
          end,
          -- Spawns "opencode acp".
          opencode = function()
            return require("codecompanion.adapters").extend("opencode", {
              defaults = { timeout = 60000 },
            })
          end,
        },
        http = {
          -- The built in "ollama" adapter is local only, it has no api_key or Authorization
          -- header, so Ollama Cloud goes through "openai_compatible" instead.
          -- Requires OLLAMA_API_KEY in the environment. Cloud models need the ":cloud" suffix.
          ollama_cloud = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "ollama_cloud",
              env = {
                url = "https://ollama.com",
                api_key = "OLLAMA_API_KEY",
                chat_url = "/v1/chat/completions",
                models_endpoint = "/v1/models",
              },
              schema = {
                model = { default = "glm-5.2:cloud" },
              },
            })
          end,
        },
      },
    },
  },

  -- Chat buffer is markdown, and the prompt library reads yaml frontmatter.
  -- yaml is already covered by plugins/lang/yaml.lua.
  {
    "romus204/tree-sitter-manager.nvim",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
}
