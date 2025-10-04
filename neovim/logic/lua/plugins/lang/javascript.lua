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
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- LSP
      table.insert(opts.ensure_installed, "typescript-language-server")

      -- DAP
      table.insert(opts.ensure_installed, "js-debug-adapter")

      -- LSP/Linter/Formatter
      if vim.fn.executable("biome") ~= 1 then
        table.insert(opts.ensure_installed, "biome")
      end
    end,
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
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        css = { "biomejs" },
        graphql = { "biomejs" },
        javascript = { "biomejs" },
        javascriptreact = { "biomejs" },
        json = { "biomejs" },
        jsonc = { "biomejs" },
        typescript = { "biomejs" },
        typescriptreact = { "biomejs" },
      },
    },
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    dependencies = {
      "mason-org/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
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
