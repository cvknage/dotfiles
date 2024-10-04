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
      integrations = {
        -- add the cmp source for completion of:
        -- `require "modname"`
        -- `---@module "modname"`
        cmp = pcall(require, 'cmp'),
        -- add the coq source for completion of:
        -- `require "modname"`
        -- `---@module "modname"`
        coq = pcall(require, 'coq_nvim'),
      },
    },
  },
}
