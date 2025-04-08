local utils = require("plugins.lang.dotnet-utils")

return {
  -- copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    enabled = utils.has_dotnet,
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
    enabled = utils.has_dotnet,
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
    enabled = utils.has_dotnet,
    keys = {
      { "<leader>ac", "<cmd>CopilotChatToggle<cr>", desc = "Copilot Chat" },
    },
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
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
