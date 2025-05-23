return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "bash" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { ensure_installed = { "bashls" } },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
      },
      formatters = {
        shfmt = {
          prepend_args = function()
            local editorconfig = vim.fn.findfile(".editorconfig", ".;")
            if editorconfig ~= "" then
              return {}
            else
              return { "-i", "2", "-ci" } -- 2 spaces and indent switch cases
            end
          end,
        },
      },
      disable_format_on_save_for_ft = { "sh", "bash", "zsh" },
    },
  },
}
