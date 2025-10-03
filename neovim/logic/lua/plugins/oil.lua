-- Disable opening Netrw when starting nvim
vim.cmd("autocmd VimEnter * ++once silent! autocmd! FileExplorer *")

-- Disable LSP / completion for oil buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = "oil",
  callback = function()
    vim.b.lsp_disabled = true
    vim.b.completion = false

    -- nvim-cmp
    local has_cmp, cmp = pcall(require, "cmp")
    if has_cmp then
      cmp.setup.buffer({ enabled = false })
    end

    -- coq.nvim
    local has_coq, coq = pcall(require, "coq")
    if has_coq and coq.Now then
      coq.Now("disable", vim.api.nvim_get_current_buf())
    end
  end,
})

return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    keys = {
      { "<leader>pv", "<cmd>Oil<cr>", desc = "Project Volumes" },
    },
    opts = {
      default_file_explorer = false,
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["l"] = "actions.select",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview_right",
        ["<C-d>"] = "actions.preview_scroll_down",
        ["<C-u>"] = "actions.preview_scroll_up",
        ["<C-c>"] = "actions.close",
        ["<A-r>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["h"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
      },
      use_default_keymaps = false,
      view_options = {
        show_hidden = true,
      },
    },
    config = function(_, opts)
      local oil = require("oil")

      local util = require("oil.util")
      local actions = require("oil.actions")
      actions.preview_right = {
        desc = "Open the entry under the cursor in a preview window on the right, or close the preview window if already open",
        callback = function()
          local entry = oil.get_cursor_entry()
          if not entry then
            vim.notify("Could not find entry under cursor", vim.log.levels.ERROR)
            return
          end
          local winid = util.get_preview_win()
          if winid then
            local cur_id = vim.w[winid].oil_entry_id
            if entry.id == cur_id then
              vim.api.nvim_win_close(winid, true)
              return
            end
          end
          oil.open_preview({
            vertical = true,
            split = "belowright", -- "aboveleft"|"belowright"|"topleft"|"botright"
          })
        end,
      }

      oil.setup(opts)

      local args = vim.v.argv
      for _, arg in ipairs(args) do
        if vim.fn.isdirectory(arg) == 1 then
          oil.open()
          break
        end
      end
    end,
  },
}
