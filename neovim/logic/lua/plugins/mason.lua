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
  -- config = true,
  config = function(_, _)
    -- Add custom mason registry to allow mason to download roslyn: 
    -- https://github.com/seblj/roslyn.nvim/issues/11#issuecomment-2294820871
    -- Remove this config section and use "config = true" instead when mason has the roslyn package natievly
    require('mason').setup({
        registries = {
            'github:mason-org/mason-registry',
            'github:syndim/mason-registry' -- https://github.com/Syndim/mason-registry
        },
    })
  end
  ,
}
