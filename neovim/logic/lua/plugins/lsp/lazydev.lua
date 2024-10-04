return {
  {
    "folke/lazydev.nvim",
    dependencies = { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
    ft = "lua",
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
    config = function(_, opts)
      local has_cmp = pcall(require, 'cmp')
      local has_coq = pcall(require, 'coq_nvim')
      local local_opts = {
        integrations = {
          -- add the cmp source for completion of:
          -- `require "modname"`
          -- `---@module "modname"`
          cmp = has_cmp,
          -- add the coq source for completion of:
          -- `require "modname"`
          -- `---@module "modname"`
          coq = has_coq,
        },
      }
      local options = vim.tbl_deep_extend(
        "force",
        opts,
        local_opts
      )
      require('lazydev').setup(options)
    end,
  },
}
