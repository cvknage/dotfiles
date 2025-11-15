local M = {}

M.is_work_config = os.getenv("HOME_CONFIGURATION_CONTEXT") == "work"
M.is_private_config = os.getenv("HOME_CONFIGURATION_CONTEXT") == "private"

return M
