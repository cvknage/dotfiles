if vim.g.vscode then
  -- VSCode extension
  require("config.autocmds")
  require("config.keymaps")
  require("config.options")

  -- https://github.com/vscode-neovim/vscode-neovim#%EF%B8%8F-keybindings-shortcuts
  vim.keymap.set("n", "<leader><space>", "<cmd>Find<cr>")
  vim.keymap.set("n", "<leader>ff", "<cmd>Find<cr>")
  vim.keymap.set("n", "<leader>/", function() require('vscode-neovim').call('workbench.action.findInFiles') end)
  vim.keymap.set("n", "<leader>cf", function() require('vscode-neovim').call('editor.action.formatDocument') end)
else
  -- ordinary Neovim
  require("config.autocmds")
  require("config.keymaps")
  require("config.lazy")
  require("config.options")
end
