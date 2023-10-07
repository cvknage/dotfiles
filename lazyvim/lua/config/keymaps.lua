-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Functional wrapper for mapping custom keybindings
local function map(mode, lhs, rhs, opts)
  local options = {}

  if opts then
    options = vim.tbl_extend("force", options, opts)
  end

  vim.keymap.set(mode, lhs, rhs, options)
end

-- lazygit - from LazyVim Default
vim.keymap.del("n", "<leader>gg")
vim.keymap.del("n", "<leader>gG")

-- floating terminal - from LazyVim Default
vim.keymap.del("n", "<leader>ft")
vim.keymap.del("n", "<leader>fT")
vim.keymap.del("n", "<c-/>")
vim.keymap.del("n", "<c-_>")

map("n", "J", "mzJ`z") -- J cursor position stay in place
map("n", "<C-u>", "<C-u>zz") -- half page up cursor position stay in place
map("n", "<C-d>", "<C-d>zz") -- half page down cursor position stay in place

map({ "n", "v" }, "<C-y>", [["+y]], { desc = "Yank to +y" }) -- yank to +y aka. sytem clipboard
map("n", "<C-y><C-y>", [["+Y]], { desc = "Yank line to +y" }) -- yank line to +y aka. sytem clipboard
map("n", "<C-S-Y>", [["+y$]], { desc = "Yank rest of line to +y" }) -- Yank rest of line to +y aka. sytem clipboard

map("x", "<C-p>", [["_dP]], { desc = "Paste over without yank" }) -- paste over without picking up what was under
map({ "n", "v" }, "<C-d>", [["_d]], { desc = "Delete selection without yank" }) -- delete selection without picking up what was under

map("n", "<leader>cs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Swap word" }) -- swap/replace marked word

map("n", "<F5>", require("dap").continue) -- debugger continue
map("n", "<F10>", require("dap").step_over) -- debugger step over
map("n", "<F11>", require("dap").step_into) -- debugger step into
map("n", "<F12>", require("dap").step_out) -- debugger step out
