local dotnet_utils = require("plugins.lang.dotnet.utils")

if dotnet_utils.has_dotnet then
  vim.lsp.config("roslyn", {
    handlers = {
      -- https://neovim.io/doc/user/lsp.html
      -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
      ["workspace/inlayHint/refresh"] = function(_, _, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if client ~= nil and client:supports_method("textDocument/inlayHint") then
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
      ]]

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
      },
    },
  })
end

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Add custom registry for Roslyn
      -- https://github.com/Crashdummyy/mason-registry
      -- https://github.com/Crashdummyy/roslynLanguageServer
      table.insert(opts.registries, "github:Crashdummyy/mason-registry")

      if dotnet_utils.has_dotnet then
        -- LSP
        table.insert(opts.ensure_installed, "roslyn")
      end
    end,
  },
  {
    "seblyng/roslyn.nvim", -- An upgraded fork of jmederosalvarado/roslyn.nvim
    enabled = dotnet_utils.has_dotnet,
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
  },
}
