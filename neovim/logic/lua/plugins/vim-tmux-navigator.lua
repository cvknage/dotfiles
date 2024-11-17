return {
  "christoomey/vim-tmux-navigator",
  enabled = vim.fn.executable("tmux") == 1,
  keys = {
    { "<C-h>", desc = "Go to left window" },
    { "<C-j>", desc = "Go to lower window" },
    { "<C-k>", desc = "Go to upper window" },
    { "<C-l>", desc = "Go to right window" },
  },
}
