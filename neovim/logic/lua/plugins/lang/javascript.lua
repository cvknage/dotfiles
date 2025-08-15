return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "javascript",
        "jsdoc",
        "tsx",
        "typescript",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      ensure_installed = { "ts_ls" },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        css = { "biome" },
        graphql = { "biome" },
        javascript = { "biome" },
        javascriptreact = { "biome" },
        json = { "biome" },
        jsonc = { "biome" },
        typescript = { "biome" },
        typescriptreact = { "biome" },
      },
      formatters = {
        biome = {
          require_cwd = true,
        },
      },
    },
  },
  {
    "zapling/mason-conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ignore_install = opts.ignore_install or {}
      if vim.fn.executable("biome") == 1 then
        table.insert(opts.ignore_install, "biome")
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    dependencies = {
      "mason-org/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      ensure_installed = { "js" },
      handlers = {
        js = function(config)
          config.name = "pwa-node"
          config.adapters = {
            type = "server",
            host = "localhost",
            port = "${port}",
            executable = {
              command = "node",
              args = {
                --[[
                require("mason-registry").get_package("js-debug-adapter"):get_install_path()
                  .. "/js-debug/src/dapDebugServer.js",
                ]]
                vim.fn.exepath("js-debug-adapter"),
                "${port}",
              },
            },
          }
          config.configurations = {
            {
              type = "pwa-node",
              request = "launch",
              name = "Launch file",
              program = "${file}",
              cwd = "${workspaceFolder}",
            },
            {
              type = "pwa-node",
              request = "attach",
              name = "Attach",
              processId = require("dap.utils").pick_process,
              cwd = "${workspaceFolder}",
            },
          }
          config.filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  },
}
