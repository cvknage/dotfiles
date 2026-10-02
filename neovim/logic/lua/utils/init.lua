local M = {}

M.is_work_config = os.getenv("HOME_CONFIGURATION_CONTEXT") == "work"
M.is_private_config = os.getenv("HOME_CONFIGURATION_CONTEXT") == "private"

-- Only "latte" is light to Catppuccin; flavour switching is driven directly
-- (see auto-dark-mode.lua), never via a `background`-watching autocmd.
M.light_flavour = "frappe"
M.dark_flavour = "mocha"

return M
