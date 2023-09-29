-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "J", "mzJ`z") -- J cursor position stay in place
vim.keymap.set("n", "<C-u>", "<C-u>zz") -- half page up cursor position stay in place
vim.keymap.set("n", "<C-d>", "<C-d>zz") -- half page down cursor position stay in place

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]]) -- yank to +y aka. sytem clipboard
vim.keymap.set("n", "<leader>Y", [["+Y]]) -- Yank to +y aka. sytem clipboard

vim.keymap.set("x", "<leader>p", [["_dP]]) -- paste over without picking up what was under
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]]) -- delete selection without picking up what was under

vim.keymap.set("n", "<leader>cs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Swap marked word" }) -- swap/replace marked word
