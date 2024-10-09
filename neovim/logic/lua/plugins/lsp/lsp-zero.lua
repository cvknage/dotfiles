-- template from: https://lsp-zero.netlify.app/docs/guide/lazy-loading-with-lazy-nvim.html --> Expand automatic setup of LSP servers
return {
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v4.x",
    lazy = true,
    config = false,
    init = function()
      -- Disable border floaring windows
      vim.g.lsp_zero_ui_float_border = "none"
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    version = false, -- latest release (as of Nov 4 2023) was v0.0.1 (on Aug 14 2022)
    event = "InsertEnter",
    dependencies = {
      {
        {
          "L3MON4D3/LuaSnip",
          dependencies = {
            "rafamadriz/friendly-snippets",
            config = function()
              require("luasnip.loaders.from_vscode").lazy_load()
            end,
          },
        },
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-nvim-lsp",
        "saadparwaiz1/cmp_luasnip",
      },
      require("plugins.lsp.lazydev")
    },
    config = function()
      local lsp_zero = require("lsp-zero")
      local cmp = require("cmp")
      local cmp_action = lsp_zero.cmp_action()

      cmp.setup({
        sources = cmp.config.sources({
          { name = "path" },     -- cmp-path
          { name = 'nvim_lsp' }, -- cmp-nvim-lsp
          { name = 'luasnip' },  -- cmp_luasnip
          {
            name = "lazydev",    -- lazydev completion source for require statements and module annotations
            group_index = 0,     -- set group index to 0 to skip loading LuaLS completions
          },
        }, {
          { name = 'buffer' }, -- cmp-buffer
        }),
        snippet = {
          expand = function(args)                    -- REQUIRED - you must specify a snippet engine
            require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
          end,
        },
        formatting = vim.tbl_extend("force", lsp_zero.cmp_format({ datails = true }), { fields = { 'abbr', 'kind', 'menu' } }),
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<ESC>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-f>"] = cmp_action.luasnip_jump_forward(),
          ["<C-b>"] = cmp_action.luasnip_jump_backward(),
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
      { "williamboman/mason-lspconfig.nvim", dependencies = { "williamboman/mason.nvim", } },
    },
    config = function(_, opts)
      local lsp_utils = require("plugins.lsp.utils")
      local lsp_zero = require("lsp-zero")

      -- lsp_attach is where you enable features that only work
      -- if there is a language server active in the file
      ---@diagnostic disable-next-line: unused-local
      local lsp_attach = function(client, bufnr)
        lsp_utils.keymaps(client, bufnr)
        lsp_utils.inlay_hints(client, bufnr)
        lsp_utils.code_lens(client, bufnr)
      end

      local capabilities = vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require('cmp_nvim_lsp').default_capabilities()
      )

      lsp_zero.extend_lspconfig({
        sign_text = true,
        lsp_attach = lsp_attach,
        capabilities = capabilities
      })

      local config = {
        ensure_installed = lsp_utils.ensure_installed(),
        handlers = {
          lsp_zero.default_setup,
          lua_ls = function()
            -- (Optional) Configure lua language server for neovim
            require('lspconfig').lua_ls.setup({
              on_init = function(client)
                lsp_zero.nvim_lua_settings(client, {})
              end,
            })
          end,
        },
      }

      if type(opts.lang_opts) == "table" then
        for _, opt in pairs(opts.lang_opts) do
          table.insert(config.ensure_installed, opt.ensure_installed)
          config.handlers[opt.ensure_installed] = function()
            require("lspconfig")[opt.ensure_installed].setup(opt.lsp_options)
          end
        end
      end

      require("mason-lspconfig").setup(config)

      vim.diagnostic.config({
        virtual_text = true,
      })
    end,
  },
}
