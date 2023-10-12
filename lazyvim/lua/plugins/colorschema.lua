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
    opts = {
      transparent_background = true, -- disables setting the background color.
    },
  },
}
