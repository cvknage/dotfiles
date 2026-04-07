return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-context",
        opts = { mode = "cursor", max_lines = 5 },
        -- stylua: ignore
        keys = {
          { "<leader>ut", function() require("treesitter-context").toggle() end, desc = "Toggle Treesitter Context", },
        },
      },
    },
    build = ":TSUpdate",
    cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
    keys = {
      { "<C-space>", desc = "Increment selection" },
      { "<bs>", desc = "Decrement selection", mode = "x" },
      {
        -- https://neovim.discourse.group/t/check-if-treesitter-is-enabled-in-the-current-buffer/902/4
        -- https://neovim.io/doc/user/treesitter.html#vim.treesitter.start()
        -- https://github.com/nvim-treesitter/playground/blob/ba48c6a62a280eefb7c85725b0915e021a1a0749/lua/nvim-treesitter-playground/hl-info.lua#L56
        "<leader>uT",
        function()
          local buf = vim.api.nvim_get_current_buf()
          local highlighter = require("vim.treesitter.highlighter")
          if highlighter.active[buf] then
            vim.treesitter.stop()
            print("Treesitter Stopped")
          else
            vim.treesitter.start()
            print("TreeSitter Started")
          end
        end,
        desc = "Toggle Treesitter Highlight",
      },
    },
    opts_extend = { "ensure_installed" },
    opts = {
      install_dir = vim.fn.stdpath("data") .. "/site",
      ensure_installed = {
        "diff",
        "query",
        "regex",
        "vim",
        "vimdoc",
      },
    },
    config = function(_, opts)
      local TS = require("nvim-treesitter")

      TS.setup({
        install_dir = opts.install_dir,
      })

      if type(opts.ensure_installed) == "table" and #opts.ensure_installed > 0 then
        TS.install(opts.ensure_installed)
      end

      -- Enable tree-sitter highlighting by default (best-effort per buffer).
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}
