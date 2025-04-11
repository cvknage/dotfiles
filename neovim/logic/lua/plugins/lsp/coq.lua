return {
  "neovim/nvim-lspconfig",
  cmd = { "LspInfo", "LspInstall", "LspStart" },
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    {
      "ms-jpq/coq_nvim",
      branch = "coq",
      build = ":COQdeps",
      init = function()
        -- https://github.com/ms-jpq/coq_nvim/tree/coq/docs
        vim.g.coq_settings = {
          auto_start = "shut-up",
          keymap = {
            jump_to_mark = "<c-f>",
            bigger_preview = "",
            manual_complete_insertion_only = true,
          },
          --[[
          limits = {
            completion_auto_timeout = 1.0, -- default: 0.088
            completion_manual_timeout = 1.0 -- default: 0.66
          },
          ]]
          --
          display = {
            preview = {
              border = {
                -- To make it look like Neovim builtin hover window, use:
                { "", "NormalFloat" },
                { "", "NormalFloat" },
                { "", "NormalFloat" },
                { " ", "NormalFloat" },
                { "", "NormalFloat" },
                { "", "NormalFloat" },
                { "", "NormalFloat" },
                { " ", "NormalFloat" },
              },
            },
          },
        }
      end,
    },
    {
      "ms-jpq/coq.thirdparty",
      branch = "3p",
      config = function(_)
        require("coq_3p")({
          --[[
            -- nLUA config works, but LSP completion is better when manually configured
            { src = "nvimlua", short_name = "nLUA", conf_only = false },
            --]]
          { src = "bc", short_name = "MATH", precision = 6 },
        })
      end,
    },
    { "ms-jpq/coq.artifacts", branch = "artifacts" },
    { "williamboman/mason-lspconfig.nvim", dependencies = { "williamboman/mason.nvim" } },
    require("plugins.lsp.lazydev"),
  },
  init = function()
    -- Reserve a space in the gutter
    -- This will avoid an annoying layout shift in the screen
    vim.opt.signcolumn = "yes"
  end,
  opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {},
    handlers = {
      -- This first function is the "default handler"
      -- it applies to every language server without a "custom handler"
      function(server_name)
        require("lspconfig")[server_name].setup({})
      end,
    },
  },
  config = function(_, opts)
    local lsp_defaults = require("lspconfig").util.default_config
    local lsp_utils = require("plugins.lsp.utils")

    -- Add coq capabilities settings to lspconfig
    -- This should be executed before you configure any language server
    -- stylua: ignore
    lsp_defaults.capabilities = vim.tbl_deep_extend(
      "force",
      lsp_defaults.capabilities,
      require("coq").lsp_ensure_capabilities()
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

    for _, lsp in ipairs(lsp_utils.ensure_installed()) do
      table.insert(opts.ensure_installed, lsp)
    end

    opts.handlers.lua_ls = function()
      require("lspconfig").lua_ls.setup(lsp_utils.lsp_options().lua_ls)
    end

    local config = {
      ensure_installed = opts.ensure_installed,
      handlers = opts.handlers,
    }

    require("mason-lspconfig").setup(config)

    vim.diagnostic.config(lsp_utils.diagnostics)
  end,
}
