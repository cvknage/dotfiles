return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
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
