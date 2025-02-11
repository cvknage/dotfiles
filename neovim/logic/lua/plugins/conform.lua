local utils = require("plugins.lang.dotnet-utils")
local function contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

return {
  {
    "stevearc/conform.nvim",
    enabled = true,
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
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
        nix = { "alejandra" },
        toml = { "taplo" },
        css = { "biome" },
        graphql = { "biome" },
        javascript = { "biome" },
        javascriptreact = { "biome" },
        json = { "biome" },
        jsonc = { "biome" },
        typescript = { "biome" },
        typescriptreact = { "biome" },
        vue = { "biome" },

        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },

        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },

      format_on_save = function(bufnr)
        local filetype = vim.bo[bufnr].filetype
        local format_filetypes_on_save = {
          "nix",
          "toml",
          "css",
          "graphql",
          "javascript",
          "javascriptreact",
          "json",
          "jsonc",
          "typescript",
          "typescriptreact",
          "vue",
          -- "cs"
        }
        if contains(format_filetypes_on_save, filetype) then
          return {
            timeout_ms = 500,
          }
        end
      end,

      formatters = {
        stylua = {
          command = "stylua",
          args = function()
            local config_file = vim.fn.findfile(".stylua.toml", ".;") or vim.fn.findfile("stylua.toml", ".;")
            local editorconfig = vim.fn.findfile(".editorconfig", ".;")
            if config_file ~= "" or editorconfig ~= "" then
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
          prepend_args = function()
            local editorconfig = vim.fn.findfile(".editorconfig", ".;")
            if editorconfig ~= "" then
              return {}
            else
              return { "-i", "2", "-ci" } -- 2 spaces and indent switch cases
            end
          end,
        },
        csharpier = {
          command = "dotnet-csharpier",
          args = { "--write-stdout" },
        },
        biome = {
          require_cwd = true,
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
      }

      if not utils.has_dotnet then
        table.insert(ignore_install, "csharpier")
      end
      if vim.fn.executable("biome") == 1 then
        table.insert(ignore_install, "biome")
      end

      return {
        ignore_install = ignore_install,
      }
    end,
  },
}
