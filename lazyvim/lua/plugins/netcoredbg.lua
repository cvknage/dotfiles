-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/lsp/init.lua

return {
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
}