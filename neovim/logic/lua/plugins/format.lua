local function contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    -- FormatDisable! will disable formatting just for this buffer
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

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
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        local filetype = vim.bo[bufnr].filetype
        if contains(opts.disable_format_on_save_for_ft, filetype) then
          return
        end
        return {
          timeout_ms = 500,
        }
      end
      require("conform").setup(opts)
    end,
  },
}
