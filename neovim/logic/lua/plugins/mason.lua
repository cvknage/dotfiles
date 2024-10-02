return {
  "williamboman/mason.nvim",
  lazy = true,
  cmd = {
    "Mason",
    "MasonUpdate",
    "MasonInstall",
    "MasonUninstall",
    "MasonUninstallAll",
    "MasonLog",
  },
  config = function(_, _)
    require('mason').setup({
        registries = {
            'github:mason-org/mason-registry',
            'github:syndim/mason-registry'
        },
    })
  end
  ,
}
