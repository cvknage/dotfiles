return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "nix" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { ensure_installed = { "nil_ls" } },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        nix = { "alejandra" },
      },
    },
  },
  {
    "zapling/mason-conform.nvim",
    optional = true,
    opts = { ignore_install = { "alejandra" } },
  },
}
