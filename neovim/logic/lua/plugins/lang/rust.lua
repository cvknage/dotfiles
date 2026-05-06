return {
  {
    "romus204/tree-sitter-manager.nvim",
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
