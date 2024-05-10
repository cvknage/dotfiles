vim.cmd('autocmd VimEnter * ++once silent! autocmd! FileExplorer *')

return {
  {
    'stevearc/oil.nvim',
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- optional
    lazy = false,
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
    config = function(_, opts)
      require("oil").setup(opts)

      local args = vim.v.argv
      for _, arg in ipairs(args) do
        if vim.fn.isdirectory(arg) == 1 then
          vim.cmd('Oil')
          break
        end
      end
    end
  }
}
