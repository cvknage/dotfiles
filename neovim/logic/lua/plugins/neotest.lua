return {
  {
    "nvim-neotest/neotest",
    -- https://github.com/Issafalcon/neotest-dotnet/issues/141 and https://github.com/nvim-neotest/neotest/issues/531
    -- commit = "52fca6717ef972113ddd6ca223e30ad0abb2800c",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim", -- The repo claims it is no longer needed but it is still recommended (see: https://github.com/antoinemadec/FixCursorHold.nvim/issues/13)
      "nvim-treesitter/nvim-treesitter",
    },
    ---@type neotest.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ---@type neotest.Adapter[]
      adapters = {},
      ---@type neotest.Config.discovery
      discovery = {
        concurrent = 0,
        enabled = true,
      },
      ---@diagnostic disable-next-line: missing-fields
      status = {
        virtual_text = true,
      },
      log_level = vim.log.levels.ERROR, -- logs can be found at: ~/.local/state/nvim/neotest.log
    },
    -- stylua: ignore
    keys = {
      { "<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File" },
      { "<leader>tT", function() require("neotest").run.run(vim.loop.cwd()) end, desc = "Run All Test Files" },
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run Last" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop" },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    -- stylua: ignore
    keys = {
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest" },
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>tD", function() require("neotest").run.run_last({ strategy = "dap" }) end, desc = "Debug Last" },
    },
  },
}
