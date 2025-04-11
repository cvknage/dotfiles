return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      ensure_installed = { "rust_analyzer" },
    },
  },
}
