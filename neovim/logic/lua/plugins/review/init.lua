local review = require("plugins.review.review")

return {
  {
    "tpope/vim-fugitive",
    optional = true,
    keys = {
      { "<leader>gd", review.toggle, desc = "Toggle Review Diff" },
      { "<leader>gr", review.add_comment, desc = "Add Review Comment" },
    },
  },
}
