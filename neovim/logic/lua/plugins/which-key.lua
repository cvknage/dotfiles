return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    -- your configuration comes here or leave it empty to use the default settings
    -- refer to the configuration section: https://github.com/folke/which-key.nvim#%EF%B8%8F-configuration

    plugins = {
      spelling = { enabled = false },
    },
    icons = { mappings = false },
    spec = {
      {
        mode = { "n", "v" },
        { "<leader><tab>", group = "tabs" },
        { "<leader>a", group = "ai" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "dap" },
        { "<leader>e", group = "encoding" },
        { "<leader>ed", group = "decode" },
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>gh", group = "hunks" },
        { "<leader>gt", group = "toggle" },
        { "<leader>j", group = "json" },
        { "<leader>l", group = "language" },
        { "<leader>o", group = "obsidian" },
        { "<leader>p", group = "project" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "test" },
        { "<leader>u", group = "ui" },
        { "<leader>w", group = "windows" },
        { "<leader>x", group = "diagnostics/quickfix" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "goto" },
        { "z", group = "fold" },
      },
    },
  },
}
