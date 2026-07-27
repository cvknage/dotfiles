local lsp_utils = require("plugins.lsp.utils")

lsp_utils.global_keymaps()
lsp_utils.diagnostics()
lsp_utils.lsp_attach()

return {
  {
    "neovim/nvim-lspconfig",
    lazy = true,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    cmd = { "LspInstall", "LspUninstall" },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      automatic_enable = true,
    },
  },
}
