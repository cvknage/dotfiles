return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  enabled = false,
  dependencies = { "mason-org/mason.nvim" },
  opts = {
    ensure_installed = {
      -- you can pin a tool to a particular version
      -- { 'golangci-lint',        version = 'v1.47.0' },

      -- you can turn off/on auto_update per tool
      -- { 'bash-language-server', auto_update = true },
    },
  },
}
