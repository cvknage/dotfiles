local dotnet_utils = require("plugins.lang.dotnet.utils")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        table.insert(opts.ensure_installed, "c_sharp")
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        -- DAP
        table.insert(opts.ensure_installed, "netcoredbg")

        -- Formatter
        table.insert(opts.ensure_installed, "csharpier")
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        opts = vim.tbl_deep_extend("force", opts, {
          formatters_by_ft = {
            cs = { "csharpier" },
            xml = { "csharpier" },
          },
          formatters = {
            csharpier = {
              command = "csharpier",
              args = { "format", "$FILENAME" },
              stdin = false,
            },
          },
        })
      end
      return opts
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "Issafalcon/neotest-dotnet",
      enabled = dotnet_utils.has_dotnet,
    },
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        table.insert(opts.adapters, dotnet_utils.test_adapter())
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        local debug_adapter = dotnet_utils.debug_adapter()
        opts = vim.tbl_deep_extend("force", opts, {
          handlers = {
            [debug_adapter.adapter] = function(config)
              require("mason-nvim-dap").default_setup(debug_adapter.dap_options(config))
            end,
          },
        })
      end
      return opts
    end,
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      if dotnet_utils.has_dotnet then
        local dap = require("dap")
        local test_debug_adapter = dotnet_utils.test_debug_adapter()
        if not dap.adapters[test_debug_adapter.adapter] then
          dap.adapters[test_debug_adapter.adapter] = test_debug_adapter.config
        end
      end
    end,
  },
}
