vim.lsp.config("sourcekit", {
  cmd = { "sourcekit-lsp" },
  filetypes = {
    "swift",
  },
  root_markers = {
    ".git",
    ".sourcekit-lsp",
    "Package.swift",
    "compile_commands.json",
  },
  get_language_id = function(_, file_type)
    return file_type
  end,
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },
  },
})

vim.lsp.enable("sourcekit")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "swift" } },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- Formatter
        "swiftformat",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        swift = { "swift-format" },
      },
      disable_format_on_save_for_ft = { "swift" },
    },
  },
}
