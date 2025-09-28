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
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "x" }, desc = "Format", },
    },
    opts_extend = { "disable_format_on_save_for_ft" },
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {},
      default_format_opts = {
        lsp_format = "fallback",
      },
      formatters = {},
      disable_format_on_save_for_ft = {},
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    config = function(_, opts)
      opts.format_on_save = function(bufnr)
        local filetype = vim.bo[bufnr].filetype
        if not contains(opts.disable_format_on_save_for_ft, filetype) then
          return {
            timeout_ms = 500,
          }
        end
      end
      require("conform").setup(opts)
    end,
  },
}
