return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "markdown",
        "markdown_inline",
      },
    },
  },
  {
    "iamcco/markdown-preview.nvim",
    enabled = false, -- Trying out live-preview.nvim instead.
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = ":call mkdp#util#install()",
  },
  {
    "brianhuster/live-preview.nvim",
    cmd = { "LivePreview" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    cmd = { "RenderMarkdown" },
    ft = { "markdown" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      code = {
        -- Determines how the top / bottom of code block are rendered:
        --  thick: use the same highlight as the code body
        --  thin:  when lines are empty overlay the above & below icons
        above = "",
        -- Used below code blocks for thin border
        below = "",
        -- Highlight for code blocks
        highlight = "none",
      },
    },
    config = function(_, opts)
      local has_coq = pcall(require, "coq")
      opts.completions = {
        lsp = { enabled = not has_coq },
        coq = { enabled = has_coq },
      }
      require("render-markdown").setup(opts)
    end,
  },
}
