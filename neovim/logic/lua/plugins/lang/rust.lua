return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "rust-analyzer",
      },
    },
  },
}
