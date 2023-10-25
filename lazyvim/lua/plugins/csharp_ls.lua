do
  return {}
end

return {
  { "Decodetalkers/csharpls-extended-lsp.nvim", lazy = true },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "c_sharp" })
      end
    end,
  },
  --[[
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.csharpier)
    end,
  },
  --]]
  --[[
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
      },
      formatters = {
        csharpier = {
          command = "dotnet-csharpier",
          args = { "--write-stdout" },
        },
      },
    },
  },
  --]]
  --[[
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "csharpier")
    end,
  },
  --]]
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        csharp_ls = {
          handlers = {
            ["textDocument/definition"] = function(...)
              return require("csharpls_extended").handler(...)
            end,
          },
          keys = {
            {
              "gd",
              function()
                require("csharpls_extended").lsp_definitions()
              end,
              desc = "Goto Definition",
            },
          },
          -- enable_roslyn_analyzers = true,
          -- organize_imports_on_format = true,
          -- enable_import_completion = true,
        },
      },
      setup = {
        csharp_ls = function()
          -- setup dap config by VsCode launch.json file
          -- require("dap.ext.vscode").load_launchjs()

          local netcoredbg = {
            type = "executable",
            command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
            args = { "--interpreter=vscode" },
          }

          -- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#dotnet
          require("dap").adapters.coreclr = netcoredbg

          -- https://github.com/Issafalcon/neotest-dotnet#debugging
          require("dap").adapters.netcoredbg = netcoredbg

          require("mason-nvim-dap").setup()
        end,
      },
    },
  },
  {
    "nvim-neotest/neotest",
    dependencies = { "Issafalcon/neotest-dotnet" },
    opts = {
      -- Can be a list of adapters like what neotest expects,
      -- or a list of adapter names,
      -- or a table of adapter names, mapped to adapter configs.
      -- The adapter will then be automatically loaded with the config.
      adapters = {
        -- https://github.com/Issafalcon/neotest-dotnet#usage
        ["neotest-dotnet"] = {},
      },
      -- Example for loading neotest-go with a custom config
      -- adapters = {
      --   ["neotest-go"] = {
      --     args = { "-tags=integration" },
      --   },
      -- },
    },
  },
}
