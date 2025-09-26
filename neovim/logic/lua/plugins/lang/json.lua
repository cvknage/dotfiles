return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json", "jsonc", "json5" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "jsonls")
      vim.lsp.config("jsonls", {
        settings = {
          json = {
            format = { enable = true },
            validate = { enable = true },
          },
        },
      })
      return opts
    end,
  },
}
