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
    opts = {
      registries = {
        "github:mason-org/mason-registry",

        -- Add custom mason registry to allow mason to download roslyn.
        -- Remove this config section and use "config = true" instead when mason has the roslyn package natievly.
        "github:Crashdummyy/mason-registry",
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
}
