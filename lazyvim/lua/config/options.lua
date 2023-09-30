-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.clipboard = "" -- Disable LazyVim default sync with system clipboard
vim.opt.relativenumber = true -- Relative line numbers

vim.opt.swapfile = false -- Disable swap file - use undotree
vim.opt.backup = false -- Disable backups - use undotree
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- Undo dir for undotree
vim.opt.undofile = true -- Undo file for undotree

vim.opt.scrolloff = 8 -- Lines of context
-- vim.opt.colorcolumn = "80" -- Line length guide

-- vim.api.nvim_set_hl(0, "Normal", { bg = "none" }) -- Background
-- vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" }) -- Background
