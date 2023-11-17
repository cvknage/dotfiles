do return {} end

return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = true,
  },
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspInstall", "LspStart" },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      {
        "ms-jpq/coq_nvim",
        branch = "coq",
        init = function ()
          vim.g.coq_settings = {
            ["auto_start"] = "shut-up",
            -- ["keymap.jump_to_mark"] = "<c-n>",
            -- ["keymap.bigger_preview"] = "<c-b>",
            -- ["clients.buffers.enabled"] = false,
            -- ["clients.snippets.enabled"] = false,
            -- ["clients.tmux.enabled"] = false,
            -- ["clients.tree_sitter.enabled"] = false,
          }
        end
      },
      {
        "ms-jpq/coq.artifacts",
        branch = "artifacts",
      },
      {
        "ms-jpq/coq.thirdparty",
        branch = "3p",
      },
      { "williamboman/mason-lspconfig.nvim" },
      { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "tsserver", "omnisharp" },
        handlers = {
          lua_ls = function()
            local lua_opts = {
              on_init = function(client)
                local path = client.workspace_folders[1].name
                if not vim.loop.fs_stat(path..'/.luarc.json') and not vim.loop.fs_stat(path..'/.luarc.jsonc') then
                  client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
                    Lua = {
                      runtime = {
                        -- Tell the language server which version of Lua you're using
                        -- (most likely LuaJIT in the case of Neovim)
                        version = 'LuaJIT'
                      },
                      -- Make the server aware of Neovim runtime files
                      workspace = {
                        checkThirdParty = false,
                        library = {
                          vim.env.VIMRUNTIME
                          -- "${3rd}/luv/library"
                          -- "${3rd}/busted/library",
                        }
                        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower
                        -- library = vim.api.nvim_get_runtime_file("", true)
                      }
                    }
                  })

                  client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
                end
                return true
              end
            }
            require("lspconfig").lua_ls.setup(require("coq").lsp_ensure_capabilities(lua_opts))
            end,
          tsserver = function()
            local tsserver_opts = { }
            require("lspconfig").tsserver.setup(require("coq").lsp_ensure_capabilities(tsserver_opts))
          end,
          omnisharp = function()
            local omnisharp_opts = {
              -- Extended textDocument/definition handler that handles assembly/decompilation
              -- loading for $metadata$ documents.
              handlers = {
                ["textDocument/definition"] = require('omnisharp_extended').handler,
              },

              -- Enables support for reading code style, naming convention and analyzer
              -- settings from .editorconfig.
              enable_editorconfig_support = true,

              -- If true, MSBuild project system will only load projects for files that
              -- were opened in the editor. This setting is useful for big C# codebases
              -- and allows for faster initialization of code navigation features only
              -- for projects that are relevant to code that is being edited. With this
              -- setting enabled OmniSharp may load fewer projects and may thus display
              -- incomplete reference lists for symbols.
              enable_ms_build_load_projects_on_demand = false,

              -- Enables support for roslyn analyzers, code fixes and rulesets.
              enable_roslyn_analyzers = true,

              -- Specifies whether 'using' directives should be grouped and sorted during
              -- document formatting.
              organize_imports_on_format = true,

              -- Enables support for showing unimported types and unimported extension
              -- methods in completion lists. When committed, the appropriate using
              -- directive will be added at the top of the current file. This option can
              -- have a negative impact on initial completion responsiveness,
              -- particularly for the first few completion sessions after opening a
              -- solution.
              enable_import_completion = true,

              -- Specifies whether to include preview versions of the .NET SDK when
              -- determining which version to use for project loading.
              sdk_include_prereleases = true,

              -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
              -- true
              analyze_open_documents_only = false,

              on_attach = function(_, bufnr)
                vim.keymap.set("n", "gd", function() require('omnisharp_extended').telescope_lsp_definitions() end, vim.tbl_extend("force", { buffer = bufnr, remap = false }, { desc = "Goto Definition" }))
              end,
            }

            require("lspconfig").omnisharp.setup(require("coq").lsp_ensure_capabilities(omnisharp_opts))
          end
        },
      })

      vim.diagnostic.config({
        virtual_text = true,
      })
    end,
  },
}
