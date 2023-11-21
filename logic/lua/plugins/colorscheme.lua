return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function(_, opts)
    require('catppuccin').setup(opts)
    vim.cmd.colorscheme("catppuccin")
    vim.opt.pumblend = 10 -- Enables pseudo-transparency for the |popup-menu|
    vim.opt.winblend = 10 -- Enables pseudo-transparency for a floaring window
  end,
  opts = {
    flavour = "macchiato",         -- latte, frappe, macchiato, mocha
    transparent_background = true, -- disables setting the background color
    custom_highlights = function(colors)
      -- STYLE GUIDE: https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md
      -- DEFAULT SETTINGS: https://github.com/catppuccin/nvim/blob/main/lua/catppuccin/groups/editor.lua
      -- local U = require("catppuccin.utils.colors")                              -- utility functions
      return {
        NormalFloat = { bg = colors.base },                                     -- floaring windows like :Mason and :Lazy
        Pmenu = { bg = colors.base },                                           -- Pmenu
        Comment = { fg = colors.overlay1 },                                     -- code comments
        Visual = { bg = colors.surface2 },                                      -- visual mode selection
        VisualNOS = { bg = colors.surface2 },                                   -- visual mode selection when vim is "Not Owning the Selection".
        LineNr = { fg = colors.pink },                                          -- line numbers
        CursorLineNr = { fg = colors.rosewater },                               -- line number on cursor line
        TreesitterContextLineNumber = { fg = colors.yellow, bg = colors.base }, -- treesitter context line numbers
        -- CursorLine = { bg = color.base },                                       -- crusor line
        --[[
        -- https://github.com/catppuccin/nvim/discussions/448#discussioncomment-5560230
        CursorLine = {
          bg = U.vary_color(
            { latte = U.lighten(colors.mantle, 0.70, colors.base) },
            U.darken(colors.surface0, 0.64, colors.base)
          ),
        },
        --]]
      }
    end,
    integrations = {
      treesitter = true,
      mason = true,
      telescope = {
        enabled = true,
      },
      native_lsp = {
        enabled = true,
        virtual_text = {
          errors = { "italic" },
          hints = { "italic" },
          warnings = { "italic" },
          information = { "italic" },
        },
        underlines = {
          errors = { "underline" },
          hints = { "underline" },
          warnings = { "underline" },
          information = { "underline" },
        },
        inlay_hints = {
          background = true,
        },
      },
      cmp = true,
      which_key = true,
      illuminate = {
        enabled = true,
        lsp = false
      },
    },
  },
}
