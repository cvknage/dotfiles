return {
  {
    "neovim/nvim-lspconfig",
    lazy = false, -- REQUIRED: tell lazy.nvim to start this plugin at startup - coq does not work correctly when lazy loaded
    dependencies = {
      -- main one
      {
        "ms-jpq/coq_nvim",
        branch = "coq",
        build = ":COQdeps", -- Should be (build = "COQnow",) but this works better for me
        init = function()
          -- https://github.com/ms-jpq/coq_nvim/tree/coq/docs
          vim.g.coq_settings = {
            auto_start = "shut-up",
            keymap = {
              jump_to_mark = "<c-f>",
              bigger_preview = "",
              manual_complete_insertion_only = true,
            },
            --[[
            limits = {
              completion_auto_timeout = 1.0, -- default: 0.088
              completion_manual_timeout = 1.0, -- default: 0.66
            },
            ]]
            display = {
              preview = {
                border = {
                  -- To make it look like Neovim builtin hover window, use:
                  { "", "NormalFloat" },
                  { "", "NormalFloat" },
                  { "", "NormalFloat" },
                  { " ", "NormalFloat" },
                  { "", "NormalFloat" },
                  { "", "NormalFloat" },
                  { "", "NormalFloat" },
                  { " ", "NormalFloat" },
                },
              },
            },
          }
        end,
      },

      -- 9000+ Snippets
      { "ms-jpq/coq.artifacts", branch = "artifacts" },

      -- lua & third party sources -- See https://github.com/ms-jpq/coq.thirdparty
      -- Need to **configure separately**
      {
        "ms-jpq/coq.thirdparty",
        branch = "3p",
        config = function(_)
          require("coq_3p")({
            --[[
            -- nLUA config works, but LSP completion is better when manually configured
            { src = "nvimlua", short_name = "nLUA", conf_only = false },
            --]]
            { src = "bc", short_name = "MATH", precision = 6 },
          })
        end,
      },
    },
    opts = function(_, opts)
    -- Add coq capabilities settings to lspconfig
    -- stylua: ignore
    opts.extra_capabilities = vim.tbl_deep_extend(
      "force",
      opts.extra_capabilities or {},
      require("coq").lsp_ensure_capabilities()
    )
    end,
  },
  require("plugins.lsp.lspconfig"),
}
