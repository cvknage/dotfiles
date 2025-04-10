local dotnet_utils = require("plugins.lang.dotnet-utils")

local M = {}

M.treesitter = {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    table.insert(opts.ensure_installed, "c_sharp")
  end,
}

M.csharp_ls = {
  M.treesitter,
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
            ["textDocument/typeDefinition"] = require("csharpls_extended").handler,
          },

          on_attach = function(_, bufnr)
            vim.keymap.set("n", "gd", function()
              require("csharpls_extended").lsp_definitions()
            end, vim.tbl_extend("force", { buffer = bufnr, remap = false }, { desc = "Goto Definition" }))
          end,
        },
      }

      opts.lang_opts = opts.lang_opts or {}
      table.insert(opts.lang_opts, csharp_ls)
    end,
  },
  {
    "nvim-neotest/neotest",
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
  return M.csharp_ls
end

return M.treesitter
