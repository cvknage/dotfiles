return {
  "neovim/nvim-lspconfig",
  cmd = { "LspInfo", "LspInstall", "LspStart" },
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason-lspconfig.nvim", dependencies = { "mason-org/mason.nvim" } },
  },
  opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {},
    extra_capabilities = {},
  },
  config = function(_, opts)
    local lsp_utils = require("plugins.lsp.utils")

    -- Add extra capabilities to all clients
    vim.lsp.config("*", { capabilities = opts.extra_capabilities })

    -- LspAttach is where you enable features that only work
    -- if there is a language server active in the file
    vim.api.nvim_create_autocmd("LspAttach", {
      desc = "LSP actions",
      callback = function(ev)
        local clients = vim.lsp.get_clients({ buffer = ev.buf })
        for _, client in pairs(clients) do
          lsp_utils.keymaps(client, ev.buf)
          -- lsp_utils.inlay_hints(client, ev.buf)
          lsp_utils.code_lens(client, ev.buf)
        end
      end,
    })

    -- Configure global diagnostic options
    lsp_utils.diagnostics()

    require("mason-lspconfig").setup({
      ensure_installed = opts.ensure_installed,
    })
  end,
}
