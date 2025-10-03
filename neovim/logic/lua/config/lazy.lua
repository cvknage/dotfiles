local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- print("Lazy install dir: " .. lazypath)

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },

    -- Autocompletion
    { import = "plugins.comp.blink" },
    -- { import = "plugins.comp.cmp" },
    -- { import = "plugins.comp.coq" },

    -- Languages
    { import = "plugins.lang" },

    -- AI
    { import = "plugins.ai.copilot" },
    { import = "plugins.ai.codeium" },
    -- { import = "plugins.ai.llm" },
    -- { import = "plugins.ai.tabby" },
    -- { import = "plugins.ai.gen" },
  },
  install = { colorscheme = { "catppuccin", "habamax" } },
  dev = {
    path = "~/Code",
    patterns = { "cvknage" },
    fallback = true,
  },
})
