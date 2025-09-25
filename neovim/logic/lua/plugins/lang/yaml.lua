return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      ensure_installed = { "yamlls" },
      handlers = {
        yamlls = function()
          require("lspconfig").yamlls.setup({
            settings = {
              redhat = { telemetry = { enabled = false } },
              yaml = {
                format = {
                  enable = true,
                  -- singleQuote = true,
                },
              },
            },
          })
        end,
      },
    },
  },
}
