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
    vim.opt.winblend = 10 -- Enables pseudo-transparency for a floating window
    vim.opt.pumblend = 10 -- Enables pseudo-transparency for the |popup-menu|
    -- Enable real transparency on floating window and popup-menu: Set winblend and pumblend to 0 and set hl group NormalFloat and Pmenu to bg = "NONE".
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
        CursorLineNr = { fg = colors.rosewater },
        LineNr = { fg = colors.pink },
        NormalFloat = { bg = colors.base }, -- floating windows like :Mason and :Lazy
        FloatBorder = { bg = colors.base }, -- floating window borders like completion menu
        Pmenu = { bg = colors.base },
        Comment = { fg = colors.overlay1 },
        Visual = { bg = colors.surface2 }, -- visual mode selection
        VisualNOS = { bg = colors.surface2 }, -- visual mode selection when vim is "Not Owning the Selection".

        -- Treesitter
        TreesitterContext = { bg = colors.mantle },
        TreesitterContextLineNumber = { fg = colors.yellow, bg = colors.mantle },

        -- Telescope
        TelescopeBorder = { fg = colors.mauve, bg = colors.base },

        -- EasyDotnet
        EasyDotnetTestRunnerPassed = { fg = colors.green, style = { "bold" } },
        EasyDotnetTestRunnerFailed = { fg = colors.red, style = { "bold" } },
        EasyDotnetTestRunnerRunning = { fg = colors.yellow, style = { "italic" } },
        EasyDotnetTestRunnerSolution = { fg = colors.mauve, style = { "bold" } },
        EasyDotnetTestRunnerProject = { fg = colors.lavender },
        EasyDotnetTestRunnerDir = { fg = colors.blue },
        EasyDotnetTestRunnerPackage = { fg = colors.teal },
        EasyDotnetTestRunnerTest = { fg = colors.text },
        EasyDotnetTestRunnerSubcase = { fg = colors.overlay1 },
        EasyDotnetDebuggerFloatVariable = { fg = colors.flamingo },
        EasyDotnetDebuggerVirtualVariable = { fg = colors.rosewater, style = { "italic" } },
        EasyDotnetDebuggerVirtualException = { fg = colors.red, style = { "bold" } },
      }
    end,
    auto_integrations = true,
  },
}
