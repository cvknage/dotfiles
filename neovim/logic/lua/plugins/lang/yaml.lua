return {
  {
    "romus204/tree-sitter-manager.nvim",
    opts = { ensure_installed = { "yaml" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "yaml-language-server",
      },
    },
  },
}
