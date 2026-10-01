local dotnet_utils = require("plugins.lang.dotnet.utils")

return {
  {
    "romus204/tree-sitter-manager.nvim",
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        table.insert(opts.ensure_installed, "c_sharp")
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Formatter
      --[[
      if dotnet_utils.has_dotnet then
        table.insert(opts.ensure_installed, "csharpier")
      end
      ]]
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      if dotnet_utils.has_dotnet then
        opts = vim.tbl_deep_extend("force", opts, {
          formatters_by_ft = {
            cs = { "csharpier" },
            xml = { "csharpier" },
          },
          formatters = {
            -- csharpier from dotnet tools and dotnet only in nix devShell
            csharpier = {
              command = "dotnet",
              args = { "csharpier", "format", "$FILENAME" },
              stdin = false,
            },
            --[[
            -- csharpier from mason and a global dotnet
            csharpier = {
              command = "csharpier",
              args = { "format", "$FILENAME" },
              stdin = false,
            },
            ]]
          },
        })
      end
      return opts
    end,
  },
}
