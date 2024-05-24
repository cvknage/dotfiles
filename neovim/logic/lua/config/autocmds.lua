-- https://neovim.io/doc/user/lua.html#vim.highlight
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight_yank', {}),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- https://github.com/jaeheonji/catppuccin-nvim#usage-with-set-background
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    vim.cmd("Catppuccin " .. (vim.v.option_new == "light" and "frappe" or "mocha"))
  end,
})
