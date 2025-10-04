return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json", "jsonc", "json5" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      -- LSP
      ensure_installed = { "json-lsp" },
    },
  },
}
