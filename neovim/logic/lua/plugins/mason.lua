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
    init = function()
      -- Load telescope for ui-select before Mason
      if not package.loaded["telescope"] then
        require("lazy").load({ plugins = { "telescope.nvim" } })
      end
    end,
    opts_extend = { "registries", "ensure_installed" },
    opts = {
      registries = {
        "github:mason-org/mason-registry",
      },
      ensure_installed = {},
    },
    config = function(_, opts)
      require("mason").setup(opts)

      -- Load mason-lock after mason
      vim.schedule(function()
        require("lazy").load({ plugins = { "mason-lock.nvim" } })
      end)

      -- Install tools from ensure_installed
      vim.schedule(function()
        local registry = require("mason-registry")
        for _, tool in ipairs(opts.ensure_installed) do
          local pkg = registry.get_package(tool)
          if not pkg:is_installed() then
            pkg:install()
          end
        end
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
}
