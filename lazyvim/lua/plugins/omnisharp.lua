return {
  {
    -- Disable CSharpier formatter for C#
    -- https://www.lazyvim.org/extras/lang/omnisharp
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = nil,
    -- opts = function(_, opts)
    --   local nls = require("null-ls")
    --   table.insert(opts.sources, nls.builtins.formatting.csharpier)
    -- end,
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

          -- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#dotnet
          require("dap").adapters.coreclr = {
            type = "executable",
            command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
            args = { "--interpreter=vscode" },
          }
          require("mason-nvim-dap").setup()
        end,
      },
    },
  },
}
