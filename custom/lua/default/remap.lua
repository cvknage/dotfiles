vim.g.mapleader = " "

-- Project Volumes: opens netrw
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- move selection:
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Jcursor positio: n == append next line to this one
vim.keymap.set("n", "J", "mzJ`z")

-- cursor position: half page jumps
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- cursor position: search
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- paste over without picking up what was under
vim.keymap.set("x", "<leader>p", [["_dP]])

-- delete selection without picking up what was under
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

-- yank to +y aka. sytem clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- disable Q
-- vim.keymap.set("n", "Q", "<nop>")

-- switch project
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")

-- Format: current buffer
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- quickfix navigation
-- https://freshman.tech/vim-quickfix-and-location-list/
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

-- Swap: replace marked word
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- chmod X: current file
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

-- shout out curent file
vim.keymap.set("n", "<leader><leader>", function()
    vim.cmd("so")
end)
