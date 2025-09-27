return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "nix" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "nil_ls",
      },
    },
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
}
