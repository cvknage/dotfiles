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
        formatting = vim.tbl_extend("force", lsp_zero.cmp_format(), { fields = { 'abbr', 'kind', 'menu' } }),
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
      { "folke/neodev.nvim", opts = {} },
    },
    config = function(_, opts)
      local lsp_utils = require("plugins.lsp.utils")

      -- IMPORTANT: make sure to setup neodev BEFORE lspconfig
      require("neodev").setup({
        library = {
          plugins = {
            "nvim-dap-ui",
            "neotest"
          },
          types = true
        },
      })

      -- This is where all the LSP shenanigans will live
      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_lspconfig()

      ---@diagnostic disable-next-line: unused-local
      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings to learn the available actions
        -- lsp_zero.default_keymaps({ buffer = bufnr })

        lsp_utils.keymaps({ buf = bufnr })
      end)

      local config = {
        ensure_installed = lsp_utils.ensure_installed(),
        handlers = {
          lsp_zero.default_setup,
          lua_ls = function()
            -- (Optional) Configure lua language server for neovim
            local lua_opts = lsp_zero.nvim_lua_ls()
            require("lspconfig").lua_ls.setup(lua_opts)
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
