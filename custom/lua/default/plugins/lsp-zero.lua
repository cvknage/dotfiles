-- template from: https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/guides/lazy-loading-with-lazy-nvim.md --> Expand automatic setup of LSP servers
return {
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v3.x",
    lazy = true,
    config = false,
    init = function()
      -- Disable automatic setup, we are doing it manually
      vim.g.lsp_zero_extend_cmp = 0
      vim.g.lsp_zero_extend_lspconfig = 0

      vim.g.lsp_zero_ui_float_border = "none" -- Disable border floaring windows
    end,
  },
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = true,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    version = false, -- latest release (as of Nov 4 2023) was v0.0.1 (on Aug 14 2022)
    event = "InsertEnter",
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-nvim-lsp",
        "saadparwaiz1/cmp_luasnip",
      },
    },
    config = function()
      -- Here is where you configure the autocompletion settings.
      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_cmp()

      -- And you can configure cmp even more, if you want to.
      local cmp = require("cmp")
      local cmp_action = lsp_zero.cmp_action()

      cmp.setup({
        sources = cmp.config.sources({
          { name = "path" },     -- cmp-path
          { name = 'nvim_lsp' }, -- cmp-nvim-lsp
          { name = 'luasnip' },  -- cmp_luasnip
        }, {
          { name = 'buffer' },   -- cmp-buffer
        }),
        formatting = lsp_zero.cmp_format(),
        -- completion = { autocomplete = false },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          -- ["<Tab>"] = cmp_action.tab_complete(),
          -- ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<Tab>"] = cmp_action.luasnip_supertab(),
          -- ["<S-Tab>"] = cmp_action.select_prev_or_fallback(),
          -- ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<S-Tab>"] = cmp_action.luasnip_shift_supertab(),
          ["<ESC>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          -- ["<C-f>"] = cmp_action.luasnip_jump_forward(),
          -- ["<C-b>"] = cmp_action.luasnip_jump_backward(),
        }),
      })
    end,
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspInstall", "LspStart" },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp" },
      { "williamboman/mason-lspconfig.nvim" },
      { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },
      {
        "folke/neodev.nvim",
        opts = {}
      },
    },
    config = function()
      -- IMPORTANT: make sure to setup neodev BEFORE lspconfig
      require("neodev").setup({
        library = { plugins = { "nvim-dap-ui" }, types = true },
      })

      -- This is where all the LSP shenanigans will live
      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_lspconfig()

      local telescope_builtin = function(builtin, opts)
        return function()
          require("telescope.builtin")[builtin](opts)
        end
      end

      local options = function(opts)
        return vim.tbl_extend("force", { buffer = bufnr, remap = false }, opts)
      end

      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings to learn the available actions
        -- lsp_zero.default_keymaps({ buffer = bufnr })

        vim.keymap.set("n", "<leader>cl", "<cmd>LspInfo<cr>", options({ desc = "Lsp Info" }))
        vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, options({ desc = "Format" }))
        vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, options({ desc = "Rename" }))
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, options({ desc = "Code Action" }))
        vim.keymap.set("n", "<leader>cA", function() vim.lsp.buf.code_action({ context = { only = { "source", }, diagnostics = {}, }, }) end, options({ desc = "Source Action" }))
        -- vim.keymap.set("n", "gd", vim.lsp.buf.definition, options({ desc = "Goto Definition" }))
        vim.keymap.set("n", "gd", telescope_builtin("lsp_definitions", { reuse_win = true }), options({ desc = "Goto Definition" }))
        -- vim.keymap.set("n", "gr", vim.lsp.buf.references, options({ desc = "References" }))
        vim.keymap.set("n", "gr", telescope_builtin("lsp_references", { reuse_win = true }), options({ desc = "References" }))
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, options({ desc = "Goto Declaration" }))
        -- vim.keymap.set("n", "gI", vim.lsp.buf.implementation, options({ desc = "Goto Implementation" }))
        vim.keymap.set("n", "gI", telescope_builtin("lsp_implementations", { reuse_win = true }), options({ desc = "Goto Implementation" }))
        -- vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, options({ desc = "Goto T[y]pe Definition" }))
        vim.keymap.set("n", "gy", telescope_builtin("lsp_type_definitions", { reuse_win = true }), options({ desc = "Goto T[y]pe Definition" }))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, options({ desc = "Hover" }))
        vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))
        vim.keymap.set("i", "<c-k>", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))
      end)

      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "tsserver", "omnisharp" },
        handlers = {
          lsp_zero.default_setup,
          lua_ls = function()
            -- (Optional) Configure lua language server for neovim
            local lua_opts = lsp_zero.nvim_lua_ls()
            require("lspconfig").lua_ls.setup(lua_opts)
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
            }

            vim.keymap.set("n", "gd", function () require('omnisharp_extended').telescope_lsp_definitions() end, options({ desc = "Goto Definition" }))

            require("lspconfig").omnisharp.setup(omnisharp_opts)
          end
        },
      })

      vim.diagnostic.config({
        virtual_text = true,
      })
    end,
  },
}
