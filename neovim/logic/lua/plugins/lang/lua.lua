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
                telemetry = { enable = false }, -- disable telemetry
                hint = { enable = true }, -- enable inlay hints
                codeLens = { enable = true }, -- enable code lens
              },
            },
            on_init = function(client)
              local join = vim.fs.joinpath
              local path = client.workspace_folders[1].name

              -- Don't do anything if there is project local config
              if vim.uv.fs_stat(join(path, ".luarc.json")) or vim.uv.fs_stat(join(path, ".luarc.jsonc")) then
                vim.g.lazydev_enabled = false -- also disable lazydev
                return
              end

              --[[ handled by lazydev
              local runtime_path = vim.split(package.path, ";")
              table.insert(runtime_path, "lua/?.lua")
              table.insert(runtime_path, "lua/?/init.lua")
              ]]

              local nvim_settings = {
                --[[ handled by lazydev
                runtime = {
                  -- Tell the language server which version of Lua you're using
                  version = "LuaJIT",
                  path = runtime_path,
                },
                workspace = {
                  checkThirdParty = false,
                  library = {
                    -- Make the server aware of Neovim runtime files
                    vim.env.VIMRUNTIME,
                    vim.fn.stdpath("config"),
                    "${3rd}/luv/library",
                  },
                },
                ]]
                diagnostics = {
                  globals = { "vim" }, -- get the language server to recognize the `vim` global
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
    "folke/lazydev.nvim",
    dependencies = {
      {
        "hrsh7th/nvim-cmp",
        optional = true,
        opts = function(_, opts)
          opts.sources = opts.sources or {}
          table.insert(opts.sources, 1, {
            name = "lazydev", -- lazydev completion source for require statements and module annotations
            group_index = 0, -- set group index to 0 to skip loading LuaLS completions
          })
        end,
      },
    },
    ft = "lua",
    opts = {
      library = {
        -- Resolve library paths from nvim config
        vim.fn.stdpath("config"),
        -- Only load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
      integrations = {
        -- add the cmp source for completion of:
        -- `require "modname"`
        -- `---@module "modname"`
        cmp = true,
        -- add the coq source for completion of:
        -- `require "modname"`
        -- `---@module "modname"`
        coq = true,
      },
    },
    config = function(_, opts)
      local has_cmp = pcall(require, "cmp")
      local has_coq = pcall(require, "coq")
      opts.integrations.cmp = has_cmp
      opts.integrations.coq = has_coq
      require("lazydev").setup(opts)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
      },
      formatters = {
        stylua = {
          command = "stylua",
          args = function()
            local config_file = vim.fn.findfile(".stylua.toml", ".;") or vim.fn.findfile("stylua.toml", ".;")
            local editorconfig = vim.fn.findfile(".editorconfig", ".;")
            if config_file ~= "" or editorconfig ~= "" then
              return { "-" }
            else
              return {
                "--indent-type",
                "Spaces",
                "--indent-width",
                "2",
                "-",
              }
            end
          end,
          stdin = true,
        },
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = {
      -- one-small-step-for-vimkind must be loaded before nvim-dap to work correctly.
      {
        "jbyuki/one-small-step-for-vimkind",
        config = function()
          local dap = require("dap")
          dap.configurations.lua = {
            {
              type = "nlua",
              request = "launch",
              name = "Launch a vimkind server - Read ducuentation @ https://github.com/jbyuki/one-small-step-for-vimkind/blob/main/doc/osv.txt#L44C1-L44C11",
            },
            {
              type = "nlua",
              request = "attach",
              name = "Attach to a vimkind server runningin another Neovim instance",
            },
          }
          dap.adapters.nlua = function(callback, config)
            local server = {
              host = config.host or "127.0.0.1",
              port = config.port or 8086,
            }
            if config.request == "launch" then
              require("osv").launch(server)
            else
              server.type = "server"
              callback(server)
            end
          end
        end,
      },
    },
  },
}
