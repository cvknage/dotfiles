return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json", "jsonc", "json5" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { ensure_installed = { "jsonls" } },
  },
}
