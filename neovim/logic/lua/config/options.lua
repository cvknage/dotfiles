vim.opt.number = true -- Print line number
vim.opt.relativenumber = true -- Relative line numbers

vim.opt.tabstop = 2 -- Number of spaces tabs count for
vim.opt.softtabstop = 2 -- Number of spaces tabs count for while performing editing operatons
vim.opt.shiftwidth = 2 -- Size of an indent
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.list = true -- Show some invisible characters like tabs

vim.opt.wrap = false -- Disable line wrap
vim.opt.cursorline = true -- Enable highlighting of the current line

vim.opt.confirm = true -- Confirm to save changes before exiting modified buffer

vim.opt.swapfile = false -- Disable swap file - use undotree
vim.opt.backup = false -- Disable backup files - use undotree
vim.opt.undofile = true -- Enable undo file for undotree
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- Undo dir for undotree

vim.opt.hlsearch = true -- Enable search highlight
vim.opt.incsearch = true -- Enable incremental search
vim.opt.ignorecase = true -- Ignore case
vim.opt.smartcase = true -- Don't ignore case with capitals

vim.opt.termguicolors = true -- True color support

vim.opt.scrolloff = 8 -- Lines of context
vim.opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50 -- Save swap file and trigger CursorHold

vim.opt.colorcolumn = "120" -- Code length guide

vim.opt.foldmethod = "expr" -- Use expression folding
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- Use treesitter for expression folding
vim.opt.foldnestmax = 4 -- Maximum fold depth
vim.opt.foldlevel = 99 -- Minimum level of a fold that will be closed by default.
-- vim.opt.foldlevelstart = 1 -- Dicate upon editing a buffer what level of folds should be open by default
vim.opt.foldtext = "" -- Show first line of the fold formatted
