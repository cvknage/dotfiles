vim.g.mapleader = " " -- <leader> == space

vim.keymap.set("n", "J", "mzJ`z", { desc = "Append ling below" }) -- J cursor position stay in place
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up" }) -- half page up cursor position stay in place
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down" }) -- half page down cursor position stay in place

vim.keymap.set({ "n", "v" }, "<A-y>", [["+y]], { desc = "Yank to +y" }) -- yank to +y aka. sytem clipboard
vim.keymap.set("n", "<A-y><A-y>", [["+Y]], { desc = "Yank line to +y" }) -- yank line to +y aka. sytem clipboard
vim.keymap.set("n", "<A-S-Y>", [["+y$]], { desc = "Yank rest of line to +y" }) -- Yank rest of line to +y aka. sytem clipboard

vim.keymap.set("x", "<A-p>", [["_dP]], { desc = "Paste over without yank" }) -- paste over without picking up what was under
vim.keymap.set({ "n", "v" }, "<A-d>", [["_d]], { desc = "Delete selection without yank" }) -- delete selection without picking up what was under

vim.keymap.set({"n", "v" }, "<leader>cs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Swap word" }) -- swap/replace marked word
vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" }) -- display line diagnostic

-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Project volumes" }) -- Project Volumes: opens netrw
-- vim.keymap.set("n", "<leader>pe", vim.cmd.Lex, { desc = "Project explorer" }) -- Project Explorer: opens netrw
-- vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>") -- switch project - https://github.com/edr3x/tmux-sessionizer

-- JSON (requires jq)
if vim.fn.executable("jq") == 1 then
  vim.keymap.set("n", "<leader>jf", "<cmd>%! jq<cr>", { desc = "Format (%! jq)" })
  vim.keymap.set("n", "<leader>jc", "<cmd>%! jq -c<cr>", { desc = "Compact (%! jq -c)" })
end

-- Encoding
vim.keymap.set("n", "<leader>eb", "<cmd>. ! tr -d '\\n' | base64<cr>", { desc = "Encode base64" })
vim.keymap.set("n", "<leader>edb", "<cmd>. ! base64 -d<cr>", { desc = "Decode base64" })

vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" }) -- Clear search with <esc>

-- move lines
vim.keymap.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
vim.keymap.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
vim.keymap.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
vim.keymap.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

-- better indenting - aka. keep selection for multiple indents
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- Quickfix navigation
vim.keymap.set("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Location List" })
vim.keymap.set("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix List" })
vim.keymap.set("n", "[q", vim.cmd.cprev, { desc = "Previous quickfix" })
vim.keymap.set("n", "]q", vim.cmd.cnext, { desc = "Next quickfix" })

--keywordprg
vim.keymap.set("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- highlights under cursor
vim.keymap.set("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })

-- buffers
vim.keymap.set("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
vim.keymap.set("n", "<leader>bh", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<leader>bl", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- tabs
vim.keymap.set("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
vim.keymap.set("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
vim.keymap.set("n", "<leader><tab>h", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
vim.keymap.set("n", "<leader><tab>l", "<cmd>tabnext<cr>", { desc = "Next Tab" })
vim.keymap.set("n", "<leader><tab>F", "<cmd>tabfirst<cr>", { desc = "First Tab" })
vim.keymap.set("n", "<leader><tab>L", "<cmd>tablast<cr>", { desc = "Last Tab" })

-- windows
vim.keymap.set("n", "<leader>ww", "<C-W>p", { desc = "Other window", remap = true })
vim.keymap.set("n", "<leader>wd", "<C-W>c", { desc = "Delete window", remap = true })
vim.keymap.set("n", "<leader>w-", "<C-W>s", { desc = "Split window below", remap = true })
vim.keymap.set("n", "<leader>w|", "<C-W>v", { desc = "Split window right", remap = true })
vim.keymap.set("n", "<leader>wt", "<C-W>T", { desc = "Break window out to seperate tab", remap = true })
vim.keymap.set("n", "<leader>wo", "<C-W>o", { desc = "Close [o]ther windows", remap = true })
vim.keymap.set("n", "<leader>wh", "<C-W>h", { desc = "Go to left window", remap = true })
vim.keymap.set("n", "<leader>wj", "<C-W>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("n", "<leader>wk", "<C-W>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("n", "<leader>wl", "<C-W>l", { desc = "Go to right window", remap = true })
vim.keymap.set("n", "<leader>wm", "<C-W>|<C-W>_", { desc = "Maximize window", remap = true })
vim.keymap.set("n", "<leader>we", "<C-W>=", { desc = "Equal height and width", remap = true })

-- Move to window using the <ctrl> hjkl keys
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Resize window using <ctrl> arrow keys
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })
