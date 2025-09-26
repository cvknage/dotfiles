return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { ensure_installed = { "yamlls" } },
  },
}
