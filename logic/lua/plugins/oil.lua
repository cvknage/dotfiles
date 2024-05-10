return {
  {
    'stevearc/oil.nvim',
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- optional
    keys = {
      { "<leader>pv", "<cmd>Oil<cr>", desc = "Project Volumes" },
    },
    opts = {
      default_file_explorer = false,
      keymaps = {
        ["l"] = "actions.select",
        ["h"] = "actions.parent",
      },
      view_options = {
        show_hidden = true,
      }
    },
  }
}
