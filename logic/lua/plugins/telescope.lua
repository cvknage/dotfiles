local builtin = function(builtin, opts)
  return function()
    require("telescope.builtin")[builtin](opts)
  end
end

return {
  "nvim-telescope/telescope.nvim",
  -- tag = '0.1.3',
  -- branch = '0.1.x',
  dependencies = {
    { "nvim-lua/plenary.nvim" },
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      config = function()
        -- To get fzf loaded and working with telescope, you need to call
        -- load_extension, somewhere after setup function:
        require('telescope').load_extension('fzf')
      end
    },
  },
  cmd = "Telescope",
  keys = {
    { "<leader>,", builtin("buffers"), desc = "Buffer" },
    { "<leader>/", builtin("live_grep"), desc = "Grep" },
    { "<leader>:", builtin("command_history"), desc = "Command History" },
    { "<leader><space>", builtin("find_files"), desc = "Find files" },

    -- files
    { "<leader>fc", builtin("find_files", { cwd = vim.fn.stdpath("config") }), desc = "Find Config File" },
    { "<leader>ff", builtin("find_files"), desc = "Find files" },
    { "<leader>fg", builtin("git_files"), desc = "Find files in Git" },
    { "<leader>fr", builtin("oldfiles"), desc = "Recent" },

    -- git
    { "<leader>gc", builtin("git_commits"), desc = "commits" },
    { "<leader>gb", builtin("git_branches"), desc = "branches" },
    { "<leader>gs", builtin("git_status"), desc = "status" },

    -- search
    { "<leader>sa", builtin("autocommands"), desc = "Auto Commands" },
    { "<leader>sb", builtin("buffers"), desc = "Buffer" },
    { "<leader>sc", builtin("command_history"), desc = "Command History" },
    { "<leader>sC", builtin("commands"), desc = "Commands" },
    { "<leader>sd", builtin("diagnostics", { bufnr=0 }), desc = "Document diagnostics" },
    { "<leader>sD", builtin("diagnostics"), desc = "Workspace diagnostics" },
    { "<leader>sg", builtin("live_grep"), desc = "Grep" },
    { "<leader>sh", builtin("help_tags"), desc = "Help Pages" },
    { "<leader>sH", builtin("highlights"), desc = "Search Highlight Groups" },
    { "<leader>sk", builtin("keymaps"), desc = "Key Maps" },
    { "<leader>sM", builtin("man_pages"), desc = "Man Pages" },
    { "<leader>sm", builtin("marks"), desc = "Jump to Mark" },
    { "<leader>so", builtin("vim_options"), desc = "Options" },
    { "<leader>sr", builtin("resume"), desc = "Resume" },
    { "<leader>sR", builtin("registers"), desc = "Registers" },
    { "<leader>sw", builtin("grep_string", { word_match = "-w" }), desc = "Word" },
    { "<leader>ss", builtin("grep_string"), mode = "v", desc = "Selection" },

    -- ui
    { "<leader>uC", builtin("colorscheme", { enable_preview = true }), desc = "Colorscheme with preview" },
  },
  opts = function()
    local actions = require("telescope.actions")
    return {
      defaults = {
        winblend = 0,
        layout_config = {
          horizontal = {
            width = 0.95,
            preview_width = 0.55
          }
        },
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
