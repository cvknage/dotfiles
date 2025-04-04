local utils = require("plugins.lang.dotnet-utils")

return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    enabled = utils.has_dotnet,
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = false, -- disable ghost text
        keymap = {
          accept = false, -- handled by nvim-cmp / blink.cmp
          -- accept = "<C-a>",
          next = "<C-TAB>",
          prev = "<C-S-TAB>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
  },

  -- copilot cmp source
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = { -- this will only be evaluated if nvim-cmp is enabled
      {
        "zbirenbaum/copilot-cmp",
        enabled = utils.has_dotnet,
        opts = {},
        config = function(_, opts)
          local copilot_cmp = require("copilot_cmp")
          copilot_cmp.setup(opts)
          -- attach cmp source whenever copilot attaches
          -- fixes lazy-loading issues with the copilot cmp source
          require("lsp-zero").on_attach(function(client, bufnr)
            copilot_cmp._on_insert_enter({})
          end, "copilot")
        end,
        specs = {
          {
            "hrsh7th/nvim-cmp",
            optional = true,
            ---@param opts cmp.ConfigSchema
            opts = function(_, opts)
              table.insert(opts.sources, 1, {
                name = "copilot",
                group_index = 1,
                priority = 100,
              })
            end,
          },
        },
      },
    },
  },

  -- copilot chat
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = utils.has_dotnet,
    keys = {
      { "<leader>ac", "<cmd>CopilotChat<cr>", desc = "CopilotChat" },
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
