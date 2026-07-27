-- https://neovim.io/doc/user/lua.html#vim.hl
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  callback = function()
    vim.hl.on_yank()
  end,
})
