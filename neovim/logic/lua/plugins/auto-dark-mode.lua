local utils = require("utils")

return {
  "f-person/auto-dark-mode.nvim",
  -- https://github.com/f-person/auto-dark-mode.nvim?tab=readme-ov-file#%EF%B8%8F-configurationk
  opts = {
    -- Switch flavour directly; going through `background` fights Catppuccin's own
    -- reload-on-background-change behavior (:h 'background').
    set_dark_mode = function()
      vim.cmd("Catppuccin " .. utils.dark_flavour)
    end,
    set_light_mode = function()
      vim.cmd("Catppuccin " .. utils.light_flavour)
    end,
  },
  config = function(_, opts)
    require("auto-dark-mode").setup(opts)
    if not utils.is_work_config then
      require("auto-dark-mode").disable() -- Disable polling after initial startup
    end
  end,
}
