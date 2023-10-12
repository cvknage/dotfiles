return {
  "f-person/auto-dark-mode.nvim",
  config = {
    update_interval = 5000, -- The value is stored in milliseconds. Defaults to 3000.
    set_dark_mode = function()
      vim.api.nvim_set_option("background", "dark")
      vim.cmd("colorscheme catppuccin-mocha")
    end,
    set_light_mode = function()
      vim.api.nvim_set_option("background", "light")
      vim.cmd("colorscheme catppuccin-frappe")
    end,
  },
}
