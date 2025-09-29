-- template from: https://lsp-zero.netlify.app/docs/guide/lazy-loading-with-lazy-nvim.html --> Expand automatic setup of LSP servers
return {
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
    opts = function()
      -- Add cmp_nvim_lsp capabilities to all LSPs
      vim.lsp.config("*", {
        capabilities = vim.tbl_deep_extend(
          "force",
          vim.lsp.protocol.make_client_capabilities(),
          require("cmp_nvim_lsp").default_capabilities()
        ),
      })

      local function cmp_format(opts)
        opts = opts or {}
        local maxwidth = opts.max_width or false
        local details = type(opts.details) == "boolean" and opts.details or false
        local fields = details and { "abbr", "kind", "menu" } or { "abbr", "menu", "kind" }

        return {
          fields = fields,
          format = function(entry, item)
            local n = entry.source.name
            local label = ""

            if n == "nvim_lsp" then
              label = "[LSP]"
            elseif n == "nvim_lua" then
              label = "[nvim]"
            else
              label = string.format("[%s]", n)
            end

            if details and item.menu ~= nil then
              item.menu = string.format("%s %s", label, item.menu)
            else
              item.menu = label
            end

            if maxwidth and #item.abbr > maxwidth then
              local last = item.kind == "Snippet" and "~" or ""
              item.abbr = string.format("%s %s", string.sub(item.abbr, 1, maxwidth), last)
            end

            return item
          end,
        }
      end

      local cmp = require("cmp")
      return {
        sources = cmp.config.sources({
          { name = "path" }, -- cmp-path
          { name = "nvim_lsp" }, -- cmp-nvim-lsp
          { name = "luasnip" }, -- cmp_luasnip
        }, {
          { name = "buffer" }, -- cmp-buffer
        }),
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
            -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
          end,
        },
        formatting = cmp_format({ details = true }),
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<ESC>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-f>"] = cmp.mapping(function(fallback)
            local luasnip = require("luasnip")
            if luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-b>"] = cmp.mapping(function(fallback)
            local luasnip = require("luasnip")
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
      }
    end,
  },
}
