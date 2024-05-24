-- Pull in the wezterm API
local wezterm = require("wezterm")

local scheme_for_appearance = function(appearance)
  -- "Catppuccin Mocha" -- or Macchiato, Frappe, Latte
  if appearance:find("Dark") then
    return "Catppuccin Mocha"
  else
    return "Catppuccin Frappe"
  end
end

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices
config.initial_cols = 160
config.initial_rows = 40

config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
config.window_background_opacity = 0.95

-- and finally, return the configuration to wezterm
return config
