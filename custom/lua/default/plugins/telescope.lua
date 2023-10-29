return {
	"nvim-telescope/telescope.nvim",
	-- tag = '0.1.3',
	-- branch = '0.1.x',
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = "Telescope",
	keys = {
		-- files
		{ "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files", },
		{ "<leader>fg", function() require("telescope.builtin").git_files() end, desc = "Find files in Git", },

		-- search
		{ "<leader>sg", function() require("telescope.builtin").grep_string({ search = vim.fn.input("Grep > ") }) end, desc = "Grep", },
	},
	opts = function()
		local actions = require("telescope.actions")
		return {
			defaults = {
				mappings = {
					i = {
						["<C-Down>"] = actions.cycle_history_next,
						["<C-Up>"] = actions.cycle_history_prev,
						["<C-f>"] = actions.preview_scrolling_down,
						["<C-b>"] = actions.preview_scrolling_up,
					},
					n = {
						["q"] = actions.close,
					},
				},
			},
		}
	end,
}
