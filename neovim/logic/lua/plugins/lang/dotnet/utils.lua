local M = {}

-- has dotnet installed
M.has_dotnet = vim.fn.executable("dotnet") == 1

-- easy-dotnet (true) or manual-setup (false).
M.use_easy_dotnet = true

-- setups (roslyn.nvim's vim.lsp.config and easy-dotnet's lsp.config.settings).
M.roslyn_settings = {
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
}

-- Matches a built apphost (…/net10.0/<svc>), not the `dotnet run` wrapper. Shared by both
-- setups' "Attach to process" dap config (netcoredbg-utils.lua and easy-dotnet-utils.lua).
function M.attach_process_filter(proc)
  return proc.name:match("/net%d+%.%d+/[%w._-]+$") ~= nil and not proc.name:match("dotnet run")
end

return M
