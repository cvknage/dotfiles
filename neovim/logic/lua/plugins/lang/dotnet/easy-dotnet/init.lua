local dotnet_utils = require("plugins.lang.dotnet.utils")
local config = require("plugins.lang.dotnet.easy-dotnet.config")
local debug_attacher = require("plugins.lang.dotnet.easy-dotnet.debug-attacher")
local active = dotnet_utils.has_dotnet and dotnet_utils.use_easy_dotnet

return {
  {
    "GustavEikaas/easy-dotnet.nvim",
    enabled = active,
    ft = "cs",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local dotnet = require("easy-dotnet")
      dotnet.setup({
        lsp = {
          enabled = true,
          config = {
            settings = dotnet_utils.roslyn_settings,
          },
        },
        debugger = {
          engine = config.easy_dotnet_debugger_engine,
        },
        test_runner = {
          neotest_integration = true,
          viewmode = "vsplit",
          vsplit_width = 50,
          vsplit_pos = "belowright",
          mappings = {
            run = { lhs = "r", desc = "Run Test" },
            run_all = { lhs = "T", desc = "Run All Tests" },
            peek_stacktrace = { lhs = "o", desc = "Show Output" },
            debug_test = { lhs = "d", desc = "Debug Test" },
            go_to_file = { lhs = "i", desc = "go to file" },
            expand = { lhs = "<CR>", desc = "expand" },
            expand_node = { lhs = "e", desc = "expand node" },
            collapse_all = { lhs = "W", desc = "collapse all" },
            close = { lhs = "q", desc = "close testrunner" },
            refresh_testrunner = { lhs = "<C-r>", desc = "refresh testrunner" },
            next_failure = { lhs = "J", desc = "next failing test" },
            prev_failure = { lhs = "K", desc = "previous failing test" },
          },
        },
      })

      vim.keymap.set("n", "<leader>te", function()
        dotnet.testrunner()
      end, { desc = "Toggle easy-dotnet Summary" })
    end,
  },
  {
    "romus204/tree-sitter-manager.nvim",
    opts = function(_, opts)
      if active then
        -- easy-dotnet language injection
        table.insert(opts.ensure_installed, "sql")
        table.insert(opts.ensure_installed, "json")
        table.insert(opts.ensure_installed, "xml")
      end
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = function(_, opts)
      if active then
        table.insert(opts.adapters, require("easy-dotnet.neotest"))
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      if active then
        table.insert(opts.sources.default, "easy-dotnet")
        return vim.tbl_deep_extend("force", opts, {
          sources = {
            providers = {
              ["easy-dotnet"] = {
                name = "easy-dotnet",
                enabled = true,
                module = "easy-dotnet.completion.blink",
                score_offset = 10000,
                async = true,
              },
            },
          },
        })
      end
    end,
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      if active then
        local dap = require("dap")
        dap.configurations.cs = dap.configurations.cs or {}
        vim.list_extend(dap.configurations.cs, debug_attacher.easy_dotnet_attach_config())
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      if active then
        opts.handlers = opts.handlers or {}
        -- Suppresses a leftover netcoredbg install leaking into dap.configurations.cs.
        opts.handlers.coreclr = function() end
      end
      return opts
    end,
  },
}
