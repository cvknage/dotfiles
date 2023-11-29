local utils = require("plugins.lang.dotnet-utils")

local M = {}

M.omnisharp = {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "c_sharp")
    end,
  },
  { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local omnisharp = {
        ensure_installed = "omnisharp",
        lsp_options = {
          -- Extended textDocument/definition handler that handles assembly/decompilation
          -- loading for $metadata$ documents.
          handlers = {
            ["textDocument/definition"] = require('omnisharp_extended').handler,
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
            vim.keymap.set("n", "gd", function() require('omnisharp_extended').telescope_lsp_definitions() end, vim.tbl_extend("force", { buffer = bufnr, remap = false }, { desc = "Goto Definition" }))
          end,
        },
      }

      if type(opts.lang_opts) == "table" then
        table.insert(opts.lang_opts, omnisharp)
      else
        opts.lang_opts = { omnisharp }
      end
    end
  },
  {
    "nvim-neotest/neotest",
    dependencies = { "Issafalcon/neotest-dotnet" },
    opts = function(_, opts)
      local dotnet = {
        test_adapter = utils.test_adapter()
      }

      if type(opts.lang_opts) == "table" then
        table.insert(opts.lang_opts, dotnet)
      else
        opts.lang_opts = { dotnet }
      end
    end
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = {
          "williamboman/mason.nvim",
        },
        opts = function(_, opts)
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
      },
    },
  },
}

if vim.fn.system({ "which", "dotnet" }) ~= "" then
  return M.omnisharp
end

return {}
