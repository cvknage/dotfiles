return {
  {
    "folke/lazydev.nvim",
    dependencies = { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
    ft = "lua", -- only load on lua files
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
          cmp = has_cmp,
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
