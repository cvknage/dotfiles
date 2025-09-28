return {
  {
    "tpope/vim-fugitive",
    lazy = false,
    keys = {
      { "<leader>gf", "<cmd>Git<cr>", desc = "Fugitive" },
      { "<leader>gr", "<cmd>Gread<cr>", desc = "Read File" },
      { "<leader>gB", "<cmd>Git blame<cr>", desc = "Blame" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    cmd = { "Gitsigns" },
    opts = {
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        -- stylua: ignore start
        map('n', ']h', function()
          if vim.wo.diff then return ']h' end
          vim.schedule(function() gs.next_hunk() end)
          return '<Ignore>'
        end, { expr = true, desc = "Next Hunk" })

        map('n', '[h', function()
          if vim.wo.diff then return '[h' end
          vim.schedule(function() gs.prev_hunk() end)
          return '<Ignore>'
        end, { expr = true, desc = "Perv Hunk" })
        -- stylua: ignore end

        -- Actions
        -- stylua: ignore start
        map('n', '<leader>ghs', gs.stage_hunk, { desc = "Stage Hunk" })
        map('n', '<leader>ghr', gs.reset_hunk, { desc = "Reset Hunk" })
        map('v', '<leader>ghs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end, { desc = "Stage Hunk" })
        map('v', '<leader>ghr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end, { desc = "Reset Hunk" })
        map('n', '<leader>ghS', gs.stage_buffer, { desc = "Stage Buffer" })
        map('n', '<leader>ghu', gs.undo_stage_hunk, { desc = "Undo Stage Hunk" })
        map('n', '<leader>ghR', gs.reset_buffer, { desc = "Reset Buffer" })
        map('n', '<leader>ghp', gs.preview_hunk, { desc = "Preview Hunk" })
        map('n', '<leader>ghb', function() gs.blame_line { full = true } end, { desc = "Blame Line" })
        map('n', '<leader>ghd', gs.diffthis, { desc = "Diff This" })
        map('n', '<leader>ghD', function() gs.diffthis('~') end, { desc = "Diff This ~" })
        -- stylua: ignore end

        -- Toggle
        -- stylua: ignore start
        map('n', '<leader>gtb', gs.toggle_current_line_blame, { desc = "Toggle Current Line Blame" })
        map('n', '<leader>gtd', gs.toggle_deleted, { desc = "Toggle Deleted" })
        -- stylua: ignore end

        -- Text object
        -- stylua: ignore start
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = "GitSigns Select Hunk" })
        -- stylua: ignore end
      end,
    },
  },
}
