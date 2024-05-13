return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim", -- The repo claims it is no longer needed but it is still recommended (see: https://github.com/antoinemadec/FixCursorHold.nvim/issues/13)
    },
    opts = {
      status = { virtual_text = true },
      adapters = {},
    },
    config = function(_, opts)
      if type(opts.lang_opts) == "table" then
        for _, opt in pairs(opts.lang_opts) do
          table.insert(opts.adapters, opt.test_adapter)
        end
      end

      require("neotest").setup(opts)
    end,
    keys = {
      { "<leader>tnt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File" },
      { "<leader>tnT", function() require("neotest").run.run(vim.loop.cwd()) end, desc = "Run All Test Files" },
      { "<leader>tnr", function() require("neotest").run.run() end, desc = "Run Nearest" },
      { "<leader>tns", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>tno", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
      { "<leader>tnO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
      { "<leader>tnS", function() require("neotest").run.stop() end, desc = "Stop" },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    keys = {
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>tnd", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest" },
    },
  },
}
