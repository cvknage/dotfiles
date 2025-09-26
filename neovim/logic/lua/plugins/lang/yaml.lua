return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "yamlls")
      vim.lsp.config("yamlls", {
        settings = {
          redhat = { telemetry = { enabled = false } },
          yaml = {
            format = {
              enable = true,
              -- singleQuote = true,
            },
          },
        },
      })
      return opts
    end,
  },
}
