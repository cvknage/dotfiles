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
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    -- stylua: ignore
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = "", desc = "Format", },
    },
    opts_extend = { "ignore_format_filetypes_on_save" },
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },

        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },
      formatters = {},
      ignore_format_filetypes_on_save = {},
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    config = function(_, opts)
      opts.format_on_save = function(bufnr)
        local filetype = vim.bo[bufnr].filetype
        if not contains(opts.ignore_format_filetypes_on_save, filetype) then
          return {
            timeout_ms = 500,
          }
        end
      end
      require("conform").setup(opts)
    end,
  },
  {
    "zapling/mason-conform.nvim",
    dependencies = {
      "stevearc/conform.nvim",
      "williamboman/mason.nvim",
    },
    opts_extend = { "ignore_install" },
    opts = {
      ignore_install = {},
    },
  },
}
