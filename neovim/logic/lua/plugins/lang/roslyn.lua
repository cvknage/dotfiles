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
        local capabilities
        if pcall(require, 'cmp_nvim_lsp') then
          capabilities = vim.tbl_deep_extend(
            "force",
            vim.lsp.protocol.make_client_capabilities(),
            require('cmp_nvim_lsp').default_capabilities()
          )
        elseif pcall(require, 'coq') then
          capabilities = require("coq").lsp_ensure_capabilities()
        else
          capabilities = vim.lsp.make_client_capabilities()
        end

        return {
          -- config: https://github.com/seblj/roslyn.nvim/tree/main?tab=readme-ov-file#%EF%B8%8F-configuration
          config = {
            capabilities = capabilities,
            --[[
            -- on_attach is handled by "lsp-zero" or "coq"
            on_attach = function(client, bufnr)
              local lsp_utils = require("plugins.lsp.utils")
              lsp_utils.keymaps(client, bufnr)
              lsp_utils.inlay_hints(client, bufnr)
              lsp_utils.code_lens(client, bufnr)
            end,
            ]]
            handlers = {
              -- https://neovim.io/doc/user/lsp.html
              -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
              ["workspace/inlayHint/refresh"] = function(_, _, ctx)
                local client = vim.lsp.get_client_by_id(ctx.client_id)
                if client.supports_method("textDocument/inlayHint") then
                  local buffers = vim.lsp.get_buffers_by_client_id(ctx.client_id)
                  for _, buf in ipairs(buffers) do
                    vim.lsp.inlay_hint.enable(vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
                    vim.lsp.util._refresh("textDocument/inlayHint", { bufnr = buf })
                  end
                end
                return vim.NIL
              end,
            },
            settings = {
              --[[
                Server name would be in format {languageName}|{grouping}.{name} or {grouping}.{name} if this option can be applied to multiple languages.

                The dafault configuration for the VSCode Extension can be found like this:
                curl -s https://raw.githubusercontent.com/dotnet/vscode-csharp/refs/heads/main/package.json | jq '.contributes.configuration[] | select(.title == "Text Editor")' > defaults.json

                Match the VSCode Extensions configuration properties to the direct Roslyn properties by using this test file as reference:
                https://github.com/dotnet/vscode-csharp/blob/main/test/lsptoolshost/unitTests/configurationMiddleware.test.ts

                The VSCode Extension converts Roslyn names with this function "convertServerOptionNameToClientConfigurationName" defined here:
                https://github.com/dotnet/vscode-csharp/blob/main/src/lsptoolshost/optionNameConverter.ts
              --]]

              ["csharp|inlay_hints"] = {
                csharp_enable_inlay_hints_for_implicit_object_creation = true,
                csharp_enable_inlay_hints_for_implicit_variable_types = true,
                csharp_enable_inlay_hints_for_lambda_parameter_types = true,
                csharp_enable_inlay_hints_for_types = true,
                dotnet_enable_inlay_hints_for_indexer_parameters = true,
                dotnet_enable_inlay_hints_for_literal_parameters = true,
                dotnet_enable_inlay_hints_for_object_creation_parameters = true,
                dotnet_enable_inlay_hints_for_other_parameters = true,
                dotnet_enable_inlay_hints_for_parameters = true,
                dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = false,
                dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = false,
                dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = false,
              },
              ["csharp|background_analysis"] = {
                dotnet_analyzer_diagnostics_scope = "fullSolution",
                dotnet_compiler_diagnostics_scope = "fullSolution",
              },
              ["csharp|code_lens"] = {
                dotnet_enable_references_code_lens = true,
                dotnet_enable_tests_code_lens = false,
              },
              ["csharp|completion"] = {
                dotnet_provide_regex_completions = true,
                dotnet_show_completion_items_from_unimported_namespaces = true,
                dotnet_show_name_completion_suggestions = true,
              },
              ["csharp|symbol_search"] = {
                dotnet_search_reference_assemblies = true,
              }
            }
          },
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
