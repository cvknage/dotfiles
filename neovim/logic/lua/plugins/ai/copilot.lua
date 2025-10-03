local utils = require("utils")
local enabled = utils.is_work_config

return {
  -- copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    enabled = enabled,
    event = "InsertEnter",
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
      local has_blink = pcall(require, "blink.cmp")
      opts.suggestion.enabled = not has_cmp and not has_blink
      require("copilot").setup(opts)
    end,
  },

  -- copilot cmp
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = {
      "zbirenbaum/copilot-cmp",
      enabled = enabled,
      opts = {},
    },
    opts = function(_, opts)
      if enabled then
        table.insert(opts.sources, 1, {
          name = "copilot",
          group_index = 1,
          priority = 100,
        })
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      "fang2hou/blink-copilot",
      enabled = enabled,
    },
    opts = function(_, opts)
      if enabled then
        table.insert(opts.sources.default, "copilot")
        return vim.tbl_deep_extend("force", opts, {
          sources = {
            providers = {
              copilot = {
                name = "copilot",
                module = "blink-copilot",
                score_offset = 100,
                async = true,
              },
            },
          },
        })
      end
    end,
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
      { "nvim-lua/plenary.nvim", branch = "master" },
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
