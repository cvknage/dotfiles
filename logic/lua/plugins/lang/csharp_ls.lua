local utils = require("plugins.lang.dotnet-utils")

local M = {}

M.csharp_ls = {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "c_sharp")
    end,
  },
  { "Decodetalkers/csharpls-extended-lsp.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local csharp_ls = {
        ensure_installed = "csharp_ls",
        lsp_options = {
          -- Extended textDocument/definition handler that handles assembly/decompilation
          -- loading for $metadata$ documents.
          handlers = {
            ["textDocument/definition"] = require("csharpls_extended").handler,
          },

          on_attach = function(_, bufnr)
            vim.keymap.set("n", "gd", function() require('csharp_ls_extended').telescope_lsp_definitions() end, vim.tbl_extend("force", { buffer = bufnr, remap = false }, { desc = "Goto Definition" }))
          end,
        }
      }

      if type(opts.lang_opts) == "table" then
        table.insert(opts.lang_opts, csharp_ls)
      else
        opts.lang_opts = { csharp_ls }
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
        dependencies = { "williamboman/mason.nvim", },
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
  return M.csharp_ls
end

return {}
