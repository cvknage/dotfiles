return {
  {
    "mason-org/mason.nvim",
    dependencies = {
      -- The plugins below are technically dependant in reverse
      -- They are listed here to make them load when mason loads
      "zapling/mason-lock.nvim",
    },
    cmd = {
      "Mason",
      "MasonUpdate",
      "MasonInstall",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonLog",
    },
    -- config = true,
    config = function(_, _)
      -- Add custom mason registry to allow mason to download roslyn.
      -- Remove this config section and use "config = true" instead when mason has the roslyn package natievly.
      require("mason").setup({
        registries = {
          "github:mason-org/mason-registry",
          "github:Crashdummyy/mason-registry",
        },
      })
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
      lockfile_path = vim.fn.stdpath("config") .. "/mason-lock.json",
    },
  },
}
