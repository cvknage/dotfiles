local utils = require("plugins.lang.dotnet-utils")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp" } }
  },
  {
    {
      "seblj/roslyn.nvim", -- An updated fork of jmederosalvarado/roslyn.nvim: https://github.com/jmederosalvarado/roslyn.nvim/issues/39
      dependencies = { "williamboman/mason.nvim" },
      build = ":MasonInstall roslyn",
      enabled = utils.has_dotnet,
      ft = "cs",
      opts = function(_, opts)
        local lsp_utils = require("plugins.lsp.utils")

        local capabilities
        local on_attach
        if pcall(require, 'cmp_nvim_lsp') then
          capabilities = vim.tbl_deep_extend(
            "force",
            vim.lsp.protocol.make_client_capabilities(),
            require('cmp_nvim_lsp').default_capabilities()
          )
          on_attach = function(client, bufnr)
            lsp_utils.keymaps({ buf = bufnr })
          end
        elseif pcall(require, 'coq') then
          capabilities = require("coq").lsp_ensure_capabilities()
          on_attach = function(client, bufnr)
            lsp_utils.keymaps({ buf = bufnr })
          end
        else
          return {}
        end

        -- configurations: https://github.com/seblj/roslyn.nvim/tree/main?tab=readme-ov-file#%EF%B8%8F-configuration
        return {
          config = {
            capabilities = capabilities,
            on_attach = on_attach,
          }
        }
      end
    },
    {
      "nvim-neotest/neotest",
      dependencies = {
        "Issafalcon/neotest-dotnet",
        enabled = utils.has_dotnet,
      },
      opts = function(_, opts)
        if utils.has_dotnet then
          local dotnet = {
            test_adapter = utils.test_adapter()
          }

          if type(opts.lang_opts) == "table" then
            table.insert(opts.lang_opts, dotnet)
          else
            opts.lang_opts = { dotnet }
          end
        end
      end
    },
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        {
          "jay-babu/mason-nvim-dap.nvim",
          dependencies = { "williamboman/mason.nvim", },
          opts = function(_, opts)
            if utils.has_dotnet then
              local dotnet = {
                ensure_installed = utils.debug_adapter().ensure_installed,
                dap_options = utils.debug_adapter().dap_options,
                test_dap = utils.debug_adapter().test_dap
              }

              if type(opts.lang_opts) == "table" then
                table.insert(opts.lang_opts, dotnet)
              else
                opts.lang_opts = { dotnet }
              end
            end
          end
        },
      },
    },
  }
}
