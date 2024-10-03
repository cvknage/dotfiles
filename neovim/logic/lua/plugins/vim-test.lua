return {
  'vim-test/vim-test',
  dependencies = {
    'preservim/vimux'
  },
  keys = {
    { "<leader>tr", ":TestNearest<CR>", desc = "Run Nearest" },
    { "<leader>tt", ":TestFile<CR>",    desc = "Run File" },
    { "<leader>tT", ":TestSuite<CR>",   desc = "Run Suite" },
    { "<leader>tl", ":TestLast<CR>",    desc = "Run Last" },
    { "<leader>tg", ":TestVisit<CR>",   desc = "Go To Last" },
  },
  config = function(_, _)
    vim.cmd("let test#strategy = 'vimux'")
    vim.cmd("let test#enabled_runners = ['csharp#dotnettest']")
  end
}
