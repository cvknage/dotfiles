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
          ]]--
          display = {
            preview = {
              border = {
                -- To make it look like Neovim builtin hover window, use:
                { "",  "NormalFloat" },
                { "",  "NormalFloat" },
                { "",  "NormalFloat" },
                { " ", "NormalFloat" },
                { "",  "NormalFloat" },
                { "",  "NormalFloat" },
                { "",  "NormalFloat" },
                { " ", "NormalFloat" }
              },
            }
          },
        }
      end
    },
    {
      "ms-jpq/coq.thirdparty",
      branch = "3p",
      config = function(_)
        require("coq_3p") {
          --[[
            -- nLUA config works, but LSP completion is better when manually configured
            { src = "nvimlua", short_name = "nLUA", conf_only = false },
            --]]
          { src = "bc", short_name = "MATH", precision = 6 },
        }
      end
    },
    { "ms-jpq/coq.artifacts", branch = "artifacts", },
    { "williamboman/mason-lspconfig.nvim", dependencies = { "williamboman/mason.nvim", } },
    { "folke/neodev.nvim", opts = {} },
  },
  config = function(_, opts)
    local lsp_utils = require("plugins.lsp.utils")

    -- IMPORTANT: make sure to setup neodev BEFORE lspconfig
    require("neodev").setup({
      library = {
        plugins = {
          "nvim-dap-ui",
          "neotest"
        },
        types = true
      },
    })

    vim.api.nvim_create_autocmd('LspAttach', {
      desc = 'LSP actions',
      callback = function(event)
        lsp_utils.keymaps(event)
      end
    })

    local config = {
      ensure_installed = lsp_utils.ensure_installed(),
      handlers = {
        function(server_name)
          require("lspconfig")[server_name].setup(require("coq").lsp_ensure_capabilities(vim.lsp.protocol
            .make_client_capabilities()))
        end,
        lua_ls = function()
          require("lspconfig").lua_ls.setup(require("coq").lsp_ensure_capabilities(lsp_utils.lsp_options().neodev))
          -- require("lspconfig").lua_ls.setup(require("coq").lsp_ensure_capabilities(lsp_utils.lsp_options().lua_ls))
        end,
      },
    }

    if type(opts.lang_opts) == "table" then
      for _, opt in pairs(opts.lang_opts) do
        table.insert(config.ensure_installed, opt.ensure_installed)
        config.handlers[opt.ensure_installed] = function()
          require("lspconfig")[opt.ensure_installed].setup(require("coq").lsp_ensure_capabilities(opt.lsp_options))
        end
      end
    end

    if type(opts.rouge) == "table" then
      for _, opt in pairs(opts.rouge) do
        local capabilities = require("coq").lsp_ensure_capabilities(vim.lsp.protocol.make_client_capabilities())
        local on_attach = function(client, bufnr)
          lsp_utils.keymaps({ buf = bufnr })
        end
        opt.setup(capabilities, on_attach)
      end
    end

    require("mason-lspconfig").setup(config)

    vim.diagnostic.config({
      virtual_text = true,
    })
  end,
}
