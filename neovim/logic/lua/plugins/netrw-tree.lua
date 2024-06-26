return {
  {
    'cvknage/netrw-tree.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons' -- optional
    },
    lazy = false,
    opts = { },
    keys = {
      { "<leader>pt", "<cmd>Explore .<cr>",  desc = "Project Tree" },
      -- { "<leader>pv", "<cmd>Explore<cr>",  desc = "Project Volumes" },
      -- { "<leader>pt", "<cmd>Lexplore<cr>", desc = "Project Tree" },
      -- { "<leader>pe", "<cmd>ToggleVexplore<cr>", desc = "Project Explorer" },
    },
  }
}
