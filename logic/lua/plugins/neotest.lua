return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "Issafalcon/neotest-dotnet"
    },
    opts = {
      status = { virtual_text = true },
    },
    config = function(_, opts)
      opts.adapters = {
        require("neotest-dotnet")({
          -- Extra arguments for nvim-dap configuration
          -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
          dap = {
            -- When true debug only user-written code. To debug standard library or anything outside of "cwd" use false. Default is true.
            justMyCode = true
          },

          -- Provide any additional "dotnet test" CLI commands here. These will be applied to ALL test runs performed via neotest. These need to be a table of strings, ideally with one key-value pair per item.
          dotnet_additional_args = {
            "--verbosity detailed"
          },

          -- Tell neotest-dotnet to use either solution (requires .sln file) or project (requires .csproj or .fsproj file) as project root
          -- Note: If neovim is opened from the solution root, using the 'project' setting may sometimes find all nested projects, however,
          --       to locate all test projects in the solution more reliably (if a .sln file is present) then 'solution' is better.
          discovery_root = "project" -- Default
        })
      }
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
