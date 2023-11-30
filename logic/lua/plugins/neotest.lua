return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
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
      { "<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File" },
      { "<leader>tT", function() require("neotest").run.run(vim.loop.cwd()) end, desc = "Run All Test Files" },
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop" },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    keys = {
      ---@diagnostic disable-next-line: missing-fields
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest" },
    },
  },
}
