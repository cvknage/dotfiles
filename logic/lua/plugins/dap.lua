return {
  "mfussenegger/nvim-dap",
  dependencies = {
    { "theHamsta/nvim-dap-virtual-text", opts = {}, },
    {
      "rcarriga/nvim-dap-ui",
      keys = {
        { "<leader>du", function() require("dapui").toggle({ }) end, desc = "Dap UI" },
        { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
      },
      opts = {},
      config = function(_, opts)
        -- setup dap config by VsCode launch.json file
        require("dap.ext.vscode").load_launchjs()

        local dap = require("dap")
        local dapui = require("dapui")
        dapui.setup(opts)
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
          dapui.close()
        end
      end,
    },
    {
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = {
        "williamboman/mason.nvim",
      },
      cmd = { "DapInstall", "DapUninstall" },
      opts = {
        ensure_installed = { "js", "coreclr" },
        handlers = {
          function(config)
            require('mason-nvim-dap').default_setup(config)
          end,
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
                processId = require 'dap.utils'.pick_process,
                cwd = "${workspaceFolder}",
              }
            }
            config.filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
            require('mason-nvim-dap').default_setup(config)
          end,
          coreclr = function(config)
            -- https://github.com/Issafalcon/neotest-dotnet#debugging
            config.adapters.netcoredbg = config.adapters.coreclr
            require('mason-nvim-dap').default_setup(config)
          end,
        },
      },
    },
    {
      "jbyuki/one-small-step-for-vimkind",
      config = function()
        local dap = require("dap")

        dap.adapters.nlua = function(callback, config)
          local adapter = {
            type = "server",
            host = config.host or "127.0.0.1",
            port = config.port or 8086,
          }

          if config.start_neovim then
            local dap_run = dap.run
            dap.run = function(running_config)
              adapter.port = running_config.port
              adapter.host = running_config.host
            end
            require("osv").run_this()
            dap.run = dap_run
          end

          callback(adapter)
        end

        dap.configurations.lua = {
          {
            type = "nlua",
            request = "attach",
            name = "Run this file",
            start_neovim = {},
          },
          {
            type = "nlua",
            request = "attach",
            name = "Attach to running Neovim instance (port = 8086)",
            port = 8086,
          },
        }
      end,
    },
  },
  keys = {
    { "<F5>", function() require("dap").continue() end, desc = "Contine" },
    { "<F10>", function() require("dap").step_over() end, desc = "Step Over" },
    { "<F11>", function() require("dap").step_into() end, desc = "Step Into" },
    { "<F12>", function() require("dap").step_out() end,  desc = "Step Out" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
    { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
    { "<leader>dg", function() require("dap").goto_() end, desc = "Go to line (no execute)" },
    { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
    { "<leader>dj", function() require("dap").down() end, desc = "Down" },
    { "<leader>dk", function() require("dap").up() end, desc = "Up" },
    { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
    { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
    { "<leader>dO", function() require("dap").step_over() end, desc = "Step Over" },
    { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>ds", function() require("dap").session() end, desc = "Session" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
  },
}
