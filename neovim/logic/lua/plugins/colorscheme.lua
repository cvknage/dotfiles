local light = "frappe"
local dark = "mocha"

return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function(_, opts)
    -- The catppuccin "background" and "flavour=auto" options do not work properly, use an autocmd to make it work.
    -- https://github.com/jaeheonji/catppuccin-nvim#usage-with-set-background
    vim.api.nvim_create_autocmd("OptionSet", {
      pattern = "background",
      callback = function()
        vim.cmd("Catppuccin " .. (vim.v.option_new == "light" and light or dark))
      end,
    })

    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
    vim.opt.pumblend = 10 -- Enables pseudo-transparency for the |popup-menu|
    vim.opt.winblend = 10 -- Enables pseudo-transparency for a floating window
  end,
  opts = {
    flavour = "auto", -- latte, frappe, macchiato, mocha
    background = { -- :h background
      light = light,
      dark = dark,
    },
    transparent_background = true, -- disables setting the background color
    float = {
      transparent = true, -- enable transparent floating windows
      solid = false, -- use solid styling for floating windows, see |winborder|
    },
    custom_highlights = function(colors)
      -- STYLE GUIDE: https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md
      -- DEFAULT SETTINGS: https://github.com/catppuccin/nvim/blob/main/lua/catppuccin/groups/editor.lua
      -- local U = require("catppuccin.utils.colors") -- utility functions
      return {
        NormalFloat = { bg = colors.base }, -- floating windows like :Mason and :Lazy
        FloatBorder = { bg = colors.base }, -- floating window borders like completion menu
        Pmenu = { bg = colors.base }, -- Pmenu
        Comment = { fg = colors.overlay1 }, -- code comments
        Visual = { bg = colors.surface2 }, -- visual mode selection
        VisualNOS = { bg = colors.surface2 }, -- visual mode selection when vim is "Not Owning the Selection".
        LineNr = { fg = colors.pink }, -- line numbers
        CursorLineNr = { fg = colors.rosewater }, -- line number on cursor line
        TreesitterContext = { bg = colors.mantle }, -- treesitter context
        TreesitterContextLineNumber = { fg = colors.yellow, bg = colors.base }, -- treesitter context line numbers
        TelescopeBorder = { fg = colors.mauve, bg = colors.base },
        -- CursorLine = { bg = colors.base }, -- crusor line
        -- https://github.com/catppuccin/nvim/discussions/448#discussioncomment-5560230
        --[[
        CursorLine = {
          bg = U.vary_color(
            { latte = U.lighten(colors.mantle, 0.70, colors.base) },
            U.darken(colors.surface0, 0.64, colors.base)
          ),
        },
        ]]
      }
    end,
    auto_integrations = true,
  },
}
