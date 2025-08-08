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
    handlers = {},
    extra_capabilities = {},
  },
  config = function(_, opts)
    local lsp_defaults = require("lspconfig").util.default_config
    local lsp_utils = require("plugins.lsp.utils")

    -- Add extra capabilities to lspconfig
    -- This should be executed before you configure any language server
    -- stylua: ignore
    lsp_defaults.capabilities = vim.tbl_deep_extend(
      "force",
      lsp_defaults.capabilities,
      opts.extra_capabilities or {}
    )

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

    table.insert(
      opts.handlers,
      -- This function is the "default handler"
      -- it applies to every language server without a "custom handler"
      function(server_name)
        require("lspconfig")[server_name].setup({})
      end
    )

    require("mason-lspconfig").setup({
      automatic_installation = false,
      ensure_installed = opts.ensure_installed,
      handlers = opts.handlers,
    })
  end,
}
