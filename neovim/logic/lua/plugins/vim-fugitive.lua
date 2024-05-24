return {
  'tpope/vim-fugitive',
  lazy = false,
    keys = {
      { "<leader>gf", "<cmd>Git<cr>", desc = "Fugitive" },
      { "<leader>gr", "<cmd>Gread<cr>", desc = "Read File" },
      { "<leader>gB", "<cmd>Git blame<cr>", desc = "Blame" },
    },
}
