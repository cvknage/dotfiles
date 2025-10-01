return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json", "jsonc", "json5" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      -- LSP
      ensure_installed = { "json-lsp" },
    },
  },
}
