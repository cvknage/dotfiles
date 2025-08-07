local utils = require("utils")
local enabled = utils.is_work_config

return {
  -- copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    enabled = enabled,
    opts = {
      suggestion = {
        enabled = false,
        auto_trigger = true,
        keymap = {
          accept = "<C-y>",
          accept_word = false,
          accept_line = false,
          next = "<C-n>",
          prev = "<C-b>",
          dismiss = "<C-ESC>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
    config = function(_, opts)
      local has_cmp = pcall(require, "cmp")
      opts.suggestion.enabled = not has_cmp
      require("copilot").setup(opts)
    end,
  },

  -- copilot cmp
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    enabled = enabled,
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      {
        "hrsh7th/nvim-cmp",
        optional = true,
        opts = function(_, opts)
          opts.sources = opts.sources or {}
          table.insert(opts.sources, 1, {
            name = "copilot",
            group_index = 1,
            priority = 100,
          })
        end,
      },
    },
    opts = {},
  },

  -- copilot chat
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = enabled,
    keys = {
      { "<leader>ac", "<cmd>CopilotChatToggle<cr>", desc = "Copilot Chat" },
      { "<leader>aC", "<cmd>CopilotChatCommit<cr>", desc = "Copilot Commit" },
      { "<leader>af", "<cmd>CopilotChatFix<cr>", desc = "Copilot Fix" },
      { "<leader>ar", "<cmd>CopilotChatReview<cr>", desc = "Copilot Review" },
      { "<leader>as", "<cmd>CopilotChatStop<cr>", desc = "Copilot Stop" },
      { "<leader>at", "<cmd>CopilotChatTest<cr>", desc = "Copilot Test" },
    },
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
      -- model = "gpt-4o", -- :CopilotChatModels
      mappings = {
        reset = {
          normal = "<C-r>",
          insert = "<C-r>",
        },
      },
    },
    -- See Commands section for default commands if you want to lazy load on them
  },
}
