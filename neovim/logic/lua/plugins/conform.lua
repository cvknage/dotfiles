local utils = require("plugins.lang.dotnet-utils")

return {
  {
    "stevearc/conform.nvim",
    enabled = true,
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cF",
        function()
          require("conform").format({ async = true })
        end,
        mode = "",
        desc = "Format",
      },
    },
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        cs = { "csharpier" },

        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },

        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },

      format_on_save = { timeout_ms = 500 },

      formatters = {
        stylua = {
          command = "stylua",
          args = function()
            local config_file = vim.fn.findfile("stylua.toml", ".;")
            if config_file ~= "" then
              return { "-" }
            else
              return {
                "--indent-type",
                "Spaces",
                "--indent-width",
                "2",
                "-",
              }
            end
          end,
          stdin = true,
        },
        shfmt = {
          prepend_args = { "-i", "2" },
        },
        csharpier = {
          command = "dotnet-csharpier",
          args = { "--write-stdout" },
        },
      },
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },
  {
    "zapling/mason-conform.nvim",
    dependencies = { "stevearc/conform.nvim", "williamboman/mason.nvim" },
    opts = function(_, opts)
      local ignore_install = {
        -- "stylua",
        "shfmt",
      }

      if not utils.has_dotnet then
        table.insert(ignore_install, "csharpier")
      end

      return {
        ignore_install = ignore_install,
      }
    end,
  },
}
