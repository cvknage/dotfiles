return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP/Formatter
        "taplo",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        toml = { "taplo" },
      },
    },
  },
}
