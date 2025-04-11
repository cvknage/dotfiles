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
        cmp = true,
        -- add the coq source for completion of:
        -- `require "modname"`
        -- `---@module "modname"`
        coq = true,
      },
    },
    config = function(_, opts)
      local has_cmp = pcall(require, "cmp")
      local has_coq = pcall(require, "coq")
      opts.integrations.cmp = has_cmp
      opts.integrations.coq = has_coq
      require("lazydev").setup(opts)
    end,
  },
}
