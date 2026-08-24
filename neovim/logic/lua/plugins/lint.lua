return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    linters_by_ft = {},
    linters = {},
  },
  config = function(_, opts)
    local lint = require("lint")
    lint.linters_by_ft = opts.linters_by_ft

    -- Let lang specs define custom linters
    for name, linter in pairs(opts.linters or {}) do
      local builtin = lint.linters[name]
      if type(linter) == "table" and type(builtin) == "table" then
        lint.linters[name] = vim.tbl_deep_extend("force", builtin, linter)
      else
        lint.linters[name] = linter
      end
    end

    -- Create autocommand which carries out the actual linting on the specified events.
    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function()
        -- Only run the linter in buffers that you can modify in order to
        -- avoid superfluous noise, notably within the handy LSP pop-ups that
        -- describe the hovered symbol using Markdown.
        if vim.bo.modifiable then
          lint.try_lint()
        end
      end,
    })
  end,
}
