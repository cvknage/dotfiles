return {
  {
    -- Disable CSharpier formatter for C#
    -- https://www.lazyvim.org/extras/lang/omnisharp
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { nil },
      },
    },
  },
  {
    -- Add netcoredbg debuggger for C#
    -- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/lsp/init.lua
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
      setup = {
        omnisharp = function()
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
