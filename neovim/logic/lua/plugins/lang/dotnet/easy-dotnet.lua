local dotnet_utils = require("plugins.lang.dotnet.utils")

return {
  {
    "GustavEikaas/easy-dotnet.nvim",
    enabled = dotnet_utils.has_dotnet,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local dotnet = require("easy-dotnet")
      dotnet.setup({
        lsp = {
          enabled = false, -- use roslyn.nvim instead
        },
        test_runner = {
          viewmode = "vsplit",
          vsplit_width = 50,
          vsplit_pos = "belowright",
          mappings = {
            run_test_from_buffer = { lhs = "<leader>Tr", desc = "Run Test" },
            run_all_tests_from_buffer = { lhs = "<leader>Tt", desc = "Tun All Tests in Buffer" },
            peek_stack_trace_from_buffer = { lhs = "<leader>To", desc = "Show Output" },
            debug_test_from_buffer = { lhs = "<leader>Td", desc = "Debug Test" },

            run = { lhs = "r", desc = "Run Test" },
            run_all = { lhs = "T", desc = "Run All Tests" },
            peek_stacktrace = { lhs = "o", desc = "Show Output" },
            debug_test = { lhs = "d", desc = "Debug Test" },
            filter_failed_tests = { lhs = "f", desc = "Filter Failed Tests" },
            go_to_file = { lhs = "g", desc = "go to file" },
            expand = { lhs = "<CR>", desc = "expand" },
            expand_node = { lhs = "E", desc = "expand node" },
            expand_all = { lhs = "-", desc = "expand all" },
            collapse_all = { lhs = "W", desc = "collapse all" },
            close = { lhs = "q", desc = "close testrunner" },
            refresh_testrunner = { lhs = "<C-r>", desc = "refresh testrunner" },
          },
        },
      })

      vim.keymap.set("n", "<leader>Ts", function()
        dotnet.testrunner()
      end, { desc = "Toggle Summary" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        -- easy-dotnet language injection
        table.insert(opts.ensure_installed, "sql")
        table.insert(opts.ensure_installed, "json")
        table.insert(opts.ensure_installed, "xml")
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
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
}
