return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato", -- <catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha>
    },
  },
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = function(_, opts)
      opts.transparent_background = true -- disables setting the background color.
      vim.o.pumblend = 0 -- disable black background in popup menue.
      vim.o.winblend = 30 -- endble pseudo-transparency for floating windows.
    end,
  },
}
