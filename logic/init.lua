if vim.g.vscode then
  -- VSCode extension
  require("config.autocmds")
  require("config.keymaps")
  require("config.options")
else
  -- ordinary Neovim
  require("config.autocmds")
  require("config.keymaps")
  require("config.lazy")
  require("config.options")
end
