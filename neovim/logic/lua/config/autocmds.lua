-- https://neovim.io/doc/user/lua.html#vim.highlight
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Disable automatic newline at EOF only for Mason lockfiles
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "mason-lock-private.json", "mason-lock-work.json" },
  callback = function()
    vim.opt_local.fixendofline = false
  end,
})
