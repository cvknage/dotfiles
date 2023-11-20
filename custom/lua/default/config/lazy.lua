local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- print("Lazy install dir: " .. lazypath)

if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		{ import = "default.plugins" },
    -- { import = "default.plugins.lsp.lsp-zero" },
    { import = "default.plugins.lsp.coq" },
	},
	install = {
		colorscheme = { "catppuccin-macchiato" },
	},
})
