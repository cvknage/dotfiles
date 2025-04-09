local utils = require("utils")

return {
  -- copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    enabled = utils.is_work_config,
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
  },

  -- copilot cmp
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    enabled = utils.is_work_config,
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      {
        "hrsh7th/nvim-cmp",
        opts = function(_, opts)
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
    enabled = utils.is_work_config,
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
      model = 'gpt-4o',
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
