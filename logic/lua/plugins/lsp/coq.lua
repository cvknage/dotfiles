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
    { "williamboman/mason-lspconfig.nvim" },
    { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },
    { "folke/neodev.nvim", opts = {} },
  },
  config = function()
    local lsp_utils = require("plugins.lsp.utils")

    -- IMPORTANT: make sure to setup neodev BEFORE lspconfig
    require("neodev").setup({
      library = {
        plugins = {
          "nvim-dap-ui",
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

    require("mason-lspconfig").setup({
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
        omnisharp = function()
          require("lspconfig").omnisharp.setup(require("coq").lsp_ensure_capabilities(lsp_utils.lsp_options().omnisharp))
        end
      },
    })

    vim.diagnostic.config({
      virtual_text = true,
    })
  end,
}
