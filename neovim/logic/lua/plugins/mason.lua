-- Disable automatic newline at EOF only for Mason lockfiles
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "mason-lock-private.json", "mason-lock-work.json" },
  callback = function()
    vim.opt_local.fixendofline = false
  end,
})

return {
  {
    "mason-org/mason.nvim",
    cmd = {
      "Mason",
      "MasonUpdate",
      "MasonInstall",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonLog",
    },
    opts_extend = { "registries" },
    opts = {
      registries = {
        "github:mason-org/mason-registry",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)

      -- Load mason-lock after mason
      vim.schedule(function()
        require("lazy").load({ plugins = { "mason-lock.nvim" } })
      end)
    end,
  },
  {
    "zapling/mason-lock.nvim",
    dependencies = { "mason-org/mason.nvim" },
    cmd = {
      "MasonLock",
      "MasonLockRestore",
    },
    opts = {
      lockfile_path = vim.fn.stdpath("config")
        .. "/mason-lock"
        .. (require("utils").is_private_config and "-private" or require("utils").is_work_config and "-work" or "")
        .. ".json",
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      { "neovim/nvim-lspconfig", optional = true }, -- can be installed for the option to use lspconfig names instead of Mason names.
      { "jay-babu/mason-nvim-dap.nvim", optional = true }, -- can be installed for the option to use nvim-dap names instead of Mason names.
    },
    cmds = {
      "MasonToolsInstall",
      "MasonToolsInstallSync",
      "MasonToolsUpdate",
      "MasonToolsUpdateSync",
      "MasonToolsClean",
    },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {},
      auto_update = false,
    },
  },
}
