local dotnet_utils = require("plugins.lang.dotnet.utils")
local netcoredbg = require("plugins.lang.dotnet.manual-setup.netcoredbg")
local vstest = require("plugins.lang.dotnet.manual-setup.vstest")
local active = dotnet_utils.has_dotnet and not dotnet_utils.use_easy_dotnet

if active then
  vim.lsp.config("roslyn", {
    settings = dotnet_utils.roslyn_settings,
  })
end

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- https://github.com/Crashdummyy/mason-registry
      -- https://github.com/Crashdummyy/roslynLanguageServer
      if dotnet_utils.has_dotnet then
        table.insert(opts.registries, "github:Crashdummyy/mason-registry")
      end

      if active then
        -- LSP
        table.insert(opts.ensure_installed, "roslyn")

        -- DAP
        table.insert(opts.ensure_installed, "netcoredbg")
      end
    end,
  },
  {
    "seblyng/roslyn.nvim",
    enabled = active,
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      if active then
        opts.handlers = opts.handlers or {}
        opts.handlers.coreclr = netcoredbg.coreclr_mason_handler
      end
      return opts
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      {
        "nsidorenco/neotest-vstest",
        enabled = active,
        dependencies = { "nvim-neotest/neotest" },
      },
    },
    opts = function(_, opts)
      if active then
        table.insert(opts.adapters, vstest.neotest_vstest_adapter())
      end
    end,
  },
}
