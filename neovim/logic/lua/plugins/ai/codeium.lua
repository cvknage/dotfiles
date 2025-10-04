local utils = require("utils")
local enabled = utils.is_private_config

return {
  {
    "Exafunction/windsurf.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    enabled = enabled,
    build = ":Codeium Auth",
    event = "InsertEnter",
    keys = {
      { "<leader>ac", "<cmd>Codeium Chat<cr>", desc = "Codeium Chat" },
    },
    opts = {
      key_bindings = {
        accept = "<C-y>",
        accept_word = false,
        accept_line = false,
        clear = false,
        next = "<C-n>",
        prev = "<C-b>",
      },
    },
    config = function(_, opts)
      local has_cmp = require("lazy.core.config").plugins["nvim-cmp"] ~= nil
      local has_blink = require("lazy.core.config").plugins["blink.cmp"] ~= nil
      opts.enable_cmp_source = has_cmp
      opts.virtual_text = {
        enabled = not has_cmp and not has_blink,
      }
      require("codeium").setup(opts)
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    opts = function(_, opts)
      if enabled then
        table.insert(opts.sources, 1, {
          name = "codeium",
          group_index = 1,
          priority = 100,
        })
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      if enabled then
        table.insert(opts.sources.default, "codeium")
        return vim.tbl_deep_extend("force", opts, {
          sources = {
            providers = {
              codeium = {
                name = "Codeium",
                module = "codeium.blink",
                score_offset = 100,
                async = true,
              },
            },
          },
        })
      end
    end,
  },
}
