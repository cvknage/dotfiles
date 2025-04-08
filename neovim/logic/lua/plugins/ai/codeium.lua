local utils = require("utils")

return {
  {
    "Exafunction/windsurf.nvim",
    enabled = utils.is_private_config,
    build = ":Codeium Auth",
    event = "BufEnter",
    keys = {
      { "<leader>ac", "<cmd>Codeium Chat<cr>", desc = "Codeium Chat" },
    },
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      {
        "hrsh7th/nvim-cmp",
        opts = function(_, opts)
          table.insert(opts.sources, 1, {
            name = "codeium",
            group_index = 1,
            priority = 100,
          })
        end,
      },
    },
    config = function()
      require("codeium").setup({
        virtual_text = {
          enabled = false,
        },
        key_bindings = {
          accept = false,
          accept_word = false,
          accept_line = false,
          clear = false,
          next = "<C-TAB>",
          prev = "<C-S-TAB>",
        },
      })
    end,
  },
}
