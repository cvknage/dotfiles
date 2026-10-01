local utils = require("utils")
local enabled = utils.is_private_config

return {
  {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    enabled = enabled,
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
          opts = { show_presets = false },
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              defaults = { timeout = 60000, mcpServers = "inherit_from_config" },
              env = {
                CLAUDE_CODE_OAUTH_TOKEN = function()
                  return ""
                end,
              },
              handlers = {
                auth = function()
                  return true
                end,
              },
            })
          end,
        },
        http = {
          opts = { show_presets = false },
        },
      },
    },
  },
}
