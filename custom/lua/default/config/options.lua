vim.opt.number = true -- Print line number
vim.opt.relativenumber = true -- Relative line numbers

vim.opt.tabstop = 4 -- Number of spaces tabs count for
vim.opt.softtabstop = 4 -- Number of spaces tabs count for while performing editing operatons
vim.opt.shiftwidth = 4 -- Size of an indent
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Insert indents automatically

vim.opt.wrap = false -- Disable line wrap

vim.opt.swapfile = false -- Disable swap file - use undotree
vim.opt.backup = false -- Disable backup files - use undotree
vim.opt.undofile = true -- Enable undo file for undotree 
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- Undo dir for undotree

vim.opt.hlsearch = true -- Enable search highlight
vim.opt.incsearch = true -- Enable incremental search

vim.opt.termguicolors = true -- True color support

vim.opt.scrolloff = 8 -- Lines of context
vim.opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50 -- Save swap file and trigger CursorHold

vim.opt.colorcolumn = "120" -- Code length guide

vim.opt.pumblend = 10 -- Popup blend
vim.opt.winblend = 10 -- Window blend
