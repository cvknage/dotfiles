local M = {}

M.is_work_config = os.getenv("HOMEMANAGER_CONFIG_SCOPE") == "work"
M.is_private_config = os.getenv("HOMEMANAGER_CONFIG_SCOPE") == "private"

return M
