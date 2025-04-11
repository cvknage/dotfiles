local dotnet_utils = require("plugins.lang.dotnet-utils")

local M = {}

M.treesitter = {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    table.insert(opts.ensure_installed, "c_sharp")
  end,
}

M.omnisharp = {
  M.treesitter,
  { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    opts = {
      ensure_installed = { "omnisharp" },
      handlers = {
        omnisharp = function()
          require("lspconfig").omnisharp.setup({
            -- Extended textDocument/definition handler that handles assembly/decompilation
            -- loading for $metadata$ documents.
            handlers = {
              ["textDocument/definition"] = require("omnisharp_extended").handler,
            },

            -- Enables support for reading code style, naming convention and analyzer
            -- settings from .editorconfig.
            enable_editorconfig_support = true,

            -- If true, MSBuild project system will only load projects for files that
            -- were opened in the editor. This setting is useful for big C# codebases
            -- and allows for faster initialization of code navigation features only
            -- for projects that are relevant to code that is being edited. With this
            -- setting enabled OmniSharp may load fewer projects and may thus display
            -- incomplete reference lists for symbols.
            enable_ms_build_load_projects_on_demand = false,

            -- Enables support for roslyn analyzers, code fixes and rulesets.
            enable_roslyn_analyzers = true,

            -- Specifies whether 'using' directives should be grouped and sorted during
            -- document formatting.
            organize_imports_on_format = true,

            -- Enables support for showing unimported types and unimported extension
            -- methods in completion lists. When committed, the appropriate using
            -- directive will be added at the top of the current file. This option can
            -- have a negative impact on initial completion responsiveness,
            -- particularly for the first few completion sessions after opening a
            -- solution.
            enable_import_completion = true,

            -- Specifies whether to include preview versions of the .NET SDK when
            -- determining which version to use for project loading.
            sdk_include_prereleases = true,

            -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
            -- true
            analyze_open_documents_only = false,

            on_attach = function(_, bufnr)
              vim.keymap.set("n", "gd", function()
                require("omnisharp_extended").telescope_lsp_definitions()
              end, vim.tbl_extend(
                "force",
                { buffer = bufnr, remap = false },
                { desc = "Goto Definition" }
              ))
            end,
          })
        end,
      },
    },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "Issafalcon/neotest-dotnet" },
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        opts.adapters = opts.adapters or {}
        table.insert(opts.adapters, dotnet_utils.test_adapter())
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    dependencies = {
      "mfussenegger/nvim-dap",
      opts = function()
        if dotnet_utils.has_dotnet then
          local dap = require("dap")
          local test_dap = dotnet_utils.debug_adapter().test_dap
          if not dap.adapters["netcoredbg"] then
            dap.adapters[test_dap.adapter] = test_dap.config
          end
        end
      end,
    },
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        local debug_adapter = dotnet_utils.debug_adapter()
        vim.tbl_deep_extend("force", opts, {
          ensure_installed = debug_adapter.ensure_installed,
          handlers = {
            [debug_adapter.ensure_installed] = function(config)
              require("mason-nvim-dap").default_setup(debug_adapter.dap_options(config))
            end,
          },
        })
      end
    end,
  },
}

if vim.fn.executable("dotnet") == 1 then
  return M.omnisharp
end

return M.treesitter
