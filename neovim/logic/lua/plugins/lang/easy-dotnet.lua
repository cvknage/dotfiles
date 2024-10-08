local utils = require("plugins.lang.dotnet-utils")

-- https://github.com/GustavEikaas/easy-dotnet.nvim
return {
  "GustavEikaas/easy-dotnet.nvim",
  dependencies = { "nvim-lua/plenary.nvim", 'nvim-telescope/telescope.nvim', },
  -- enabled = utils.has_dotnet,
  enabled = false,
  opts = function(_, opts)
    local dotnet = require("easy-dotnet")
    return {}
  end
}
