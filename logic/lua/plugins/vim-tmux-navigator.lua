local M = {}

M.navigator = {
  "christoomey/vim-tmux-navigator",
  keys = {
    { "<C-h>", desc = "Go to left window" },
    { "<C-j>", desc = "Go to lower window" },
    { "<C-k>", desc = "Go to upper window" },
    { "<C-l>", desc = "Go to right window" },
  },
}

if vim.fn.executable("tmux") == 1 then
  return M.navigator
end

return {}
