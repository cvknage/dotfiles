return {
  {
    "romus204/tree-sitter-manager.nvim",
    opts = { ensure_installed = { "cmake" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "clangd",
        "neocmakelsp",
      },
    },
  },
}
