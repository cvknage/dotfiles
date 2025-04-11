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
        optional = true,
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
      local has_cmp = pcall(require, 'cmp')
      require("codeium").setup({
        enable_cmp_source = has_cmp,
        virtual_text = {
          enabled = not has_cmp,
        },
        key_bindings = {
          accept = "<C-y>",
          accept_word = false,
          accept_line = false,
          clear = false,
          next = "<C-n>",
          prev = "<C-b>",
        },
      })
    end,
  },
}
