return {
  {
    "romus204/tree-sitter-manager.nvim",
    opts = { ensure_installed = { "json", "json5" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      -- LSP
      ensure_installed = { "json-lsp" },
    },
  },
}
