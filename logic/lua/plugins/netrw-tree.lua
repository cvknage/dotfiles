return {
  {
    'cvknage/netrw-tree.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons' -- optional
    },
    lazy = false,
    keys = {
      { "<leader>pv", "<cmd>Explore<cr>",  desc = "Project Volumes" },
      { "<leader>pe", "<cmd>Lexplore<cr>", desc = "Project Extrueplorer" },
    },
  }
}
