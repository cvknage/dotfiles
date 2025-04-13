return {
  "neovim/nvim-lspconfig",
  cmd = { "LspInfo", "LspInstall", "LspStart" },
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "williamboman/mason-lspconfig.nvim", dependencies = { "williamboman/mason.nvim" } },
  },
  init = function()
    -- Reserve a space in the gutter
    -- This will avoid an annoying layout shift in the screen
    vim.opt.signcolumn = "yes"
  end,
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

    table.insert(
      opts.handlers,
      -- This function is the "default handler"
      -- it applies to every language server without a "custom handler"
      function(server_name)
        require("lspconfig")[server_name].setup({})
      end
    )

    local config = {
      ensure_installed = opts.ensure_installed,
      handlers = opts.handlers,
    }

    require("mason-lspconfig").setup(config)

    vim.diagnostic.config({
      virtual_text = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "✘",
          [vim.diagnostic.severity.WARN] = "▲",
          [vim.diagnostic.severity.HINT] = "⚑",
          [vim.diagnostic.severity.INFO] = "»",
        },
      },
    })
  end,
}
