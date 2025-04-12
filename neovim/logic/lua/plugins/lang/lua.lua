return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua",
        "luadoc",
        "luap",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      ensure_installed = { "lua_ls" },
      handlers = {
        lua_ls = function()
          require("lspconfig").lua_ls.setup({
            settings = {
              Lua = {
                telemetry = {
                  enable = false,
                },
              },
            },
            on_init = function(client)
              local join = vim.fs.joinpath
              local path = client.workspace_folders[1].name
              local runtime_path = vim.split(package.path, ";")
              table.insert(runtime_path, "lua/?.lua")
              table.insert(runtime_path, "lua/?/init.lua")

              -- Don't do anything if there is project local config
              if vim.uv.fs_stat(join(path, ".luarc.json")) or vim.uv.fs_stat(join(path, ".luarc.jsonc")) then
                return
              end

              local nvim_settings = {
                runtime = {
                  -- Tell the language server which version of Lua you're using
                  version = "LuaJIT",
                  path = runtime_path,
                },
                diagnostics = {
                  -- Get the language server to recognize the `vim` global
                  globals = { "vim" },
                },
                workspace = {
                  checkThirdParty = false,
                  library = {
                    -- Make the server aware of Neovim runtime files
                    vim.env.VIMRUNTIME,
                    "${3rd}/luv/library",
                    -- "${3rd}/busted/library",
                    vim.fn.stdpath("config"),
                  },
                },
              }

              client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, nvim_settings)
              client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
            end,
          })
        end,
      },
    },
  },
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
