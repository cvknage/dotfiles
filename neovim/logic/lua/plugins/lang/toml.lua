return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml" } },
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
