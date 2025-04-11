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
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    dependencies = {
      "williamboman/mason.nvim",
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
                require("mason-registry").get_package("js-debug-adapter"):get_install_path()
                  .. "/js-debug/src/dapDebugServer.js",
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
