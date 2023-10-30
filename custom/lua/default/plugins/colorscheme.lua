return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function(_, opts)
        require('catppuccin').setup(opts)
		vim.cmd.colorscheme("catppuccin")
	end,
	opts = {
        flavour = "macchiato", -- latte, frappe, macchiato, mocha
        background = { -- :h background
            light = "frappe",
            dark = "mocha",
        },
		transparent_background = true, -- disables setting the background color
        custom_highlights = function(color)
          return {
            NormalFloat = { bg = color.base }, -- background for floaring windows like :Mason and :Lazy
            TreesitterContextLineNumber = { bg = color.base } -- background for treesitter context line numbers
          }
        end,
        integrations = {
            treesitter = true,
            mason = true,
            telescope = {
                enabled = true,
            },
            native_lsp = {
                enabled = true,
                virtual_text = {
                    errors = { "italic" },
                    hints = { "italic" },
                    warnings = { "italic" },
                    information = { "italic" },
                },
                underlines = {
                    errors = { "underline" },
                    hints = { "underline" },
                    warnings = { "underline" },
                    information = { "underline" },
                },
                inlay_hints = {
                    background = true,
                },
            },
        },
	},
}
