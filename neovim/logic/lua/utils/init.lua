local dotnet_utils = require("plugins.lang.dotnet.utils")

local M = {}

M.is_work_config = dotnet_utils.has_dotnet
M.is_private_config = not dotnet_utils.has_dotnet

return M
