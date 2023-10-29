return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function(_, _)
		-- Catppuccin for NeoVim
		-- colorscheme ==  <catppuccin, catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha>
		vim.cmd.colorscheme("catppuccin-macchiato")

		-- Background
		vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
		vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
	end,
	opts = {
		transparent_background = true, -- disables setting the background color.
	},
}
