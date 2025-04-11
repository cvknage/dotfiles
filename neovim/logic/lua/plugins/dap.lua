return {
  -- dap config
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "theHamsta/nvim-dap-virtual-text", opts = {} },

      -- The plugins below are technically dependant in reverse
      -- They are listed here to make them load when nvim-dap loads
      "rcarriga/nvim-dap-ui",
      "jay-babu/mason-nvim-dap.nvim",
      "jbyuki/one-small-step-for-vimkind",
    },
    -- stylua: ignore
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Contine" },
      { "<F10>", function() require("dap").step_over() end, desc = "Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Step Into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Step Out" },
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
    config = function()
      -- setup dap config by VsCode launch.json file
      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end
    end,
  },

  -- dap ui config
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    -- stylua: ignore
    keys = {
        { "<leader>du", function() require("dapui").toggle({}) end, desc = "Dap UI" },
        { "<leader>de", function() require("dapui").eval() end, desc = "Eval",  mode = { "n", "v" } },
    },
    opts = {},
    config = function(_, opts)
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

  -- mason dap config
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    cmd = { "DapInstall", "DapUninstall" },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = { },
      handlers = {
        function(config)
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  },

  -- lua dap config
  {
    "jbyuki/one-small-step-for-vimkind",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    lazy = true,
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
          ---@diagnostic disable-next-line: duplicate-set-field
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
}
