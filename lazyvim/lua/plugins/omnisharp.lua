return {
  {
    -- Disable CSharpier formatter for C#
    -- https://www.lazyvim.org/extras/lang/omnisharp
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local csharpier_index
      for index, value in ipairs(opts.sources) do
        if value.name == "csharpier" then
          csharpier_index = index
          break
        end
      end
      opts.sources[csharpier_index] = nil
    end,
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
