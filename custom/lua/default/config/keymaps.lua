vim.g.mapleader = " " -- <leader> == space

vim.keymap.set("n", "J", "mzJ`z", { desc = "Append ling below" }) -- J cursor position stay in place
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up" }) -- half page up cursor position stay in place
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down" }) -- half page down cursor position stay in place

vim.keymap.set({ "n", "v" }, "<A-y>", [["+y]], { desc = "Yank to +y" }) -- yank to +y aka. sytem clipboard
vim.keymap.set("n", "<A-y><A-y>", [["+Y]], { desc = "Yank line to +y" }) -- yank line to +y aka. sytem clipboard
vim.keymap.set("n", "<A-S-Y>", [["+y$]], { desc = "Yank rest of line to +y" }) -- Yank rest of line to +y aka. sytem clipboard

vim.keymap.set("x", "<A-p>", [["_dP]], { desc = "Paste over without yank" }) -- paste over without picking up what was under
vim.keymap.set({ "n", "v" }, "<A-d>", [["_d]], { desc = "Delete selection without yank" }) -- delete selection without picking up what was under

vim.keymap.set("n", "<leader>cs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Swap word" }) -- swap/replace marked word

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Project volumes" }) -- Project Volumes: opens netrw
-- vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>") -- switch project

vim.keymap.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" }) -- move line down
vim.keymap.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" }) -- move line up
vim.keymap.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" }) -- move line down
vim.keymap.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" }) -- move line up
vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" }) -- move line down
vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" }) -- move line up

-- cursor position: search
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- disable Q
-- vim.keymap.set("n", "Q", "<nop>")

-- quickfix navigation
-- https://freshman.tech/vim-quickfix-and-location-list/
--[[
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")
--]]
