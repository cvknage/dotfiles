return {
  {
    "nvim-treesitter/nvim-treesitter",
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
    build = function()
      require("nvim-treesitter.install").update({ with_sync = true })()
    end,
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
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
      ensure_installed = {
        "c",
        "diff",
        "html",
        "json",
        "jsonc",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "vim",
        "vimdoc",
        "yaml",
      },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false,
      },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
