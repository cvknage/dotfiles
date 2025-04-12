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

    -- LSPs
    { import = "plugins.lsp.lsp-zero" },
    -- { import = "plugins.lsp.coq" },

    -- Languages
    -- { import = "plugins.lang.omnisharp" },
    -- { import = "plugins.lang.csharp_ls" },
    { import = "plugins.lang.roslyn" },
    { import = "plugins.lang.rust" },
    { import = "plugins.lang.javascript" },
    { import = "plugins.lang.lua" },
    { import = "plugins.lang.nix" },

    -- AI Code Completion
    { import = "plugins.ai.copilot" },
    { import = "plugins.ai.codeium" },
    -- { import = "plugins.ai.llm" },
    -- { import = "plugins.ai.tabby" },

    -- AI - Prompts
    -- { import = "plugins.ai.gen" },
  },
  install = {
    colorscheme = { "catppuccin-macchiato" },
  },
  dev = {
    path = "~/Code",
    patterns = { "cvknage" },
    fallback = true,
  },
})
