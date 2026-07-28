return {
  {
    "romus204/tree-sitter-manager.nvim",
    lazy = false,
    cmd = { "TSManager", "TSInstall", "TSUninstall", "TSUpdate" },
    keys = {
      {
        -- https://neovim.io/doc/user/treesitter.html#vim.treesitter.start()
        "<leader>uT",
        function()
          local buf = vim.api.nvim_get_current_buf()
          if vim.b[buf].ts_highlight then
            vim.treesitter.stop()
            print("Treesitter Stopped")
          else
            vim.treesitter.start()
            print("Treesitter Started")
          end
        end,
        desc = "Toggle Treesitter Highlight",
      },
    },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "diff",
        "regex",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = { mode = "cursor", max_lines = 5 },
    -- stylua: ignore
    keys = {
      { "<leader>ut", function() require("treesitter-context").toggle() end, desc = "Toggle Treesitter Context", },
    },
  },
}
