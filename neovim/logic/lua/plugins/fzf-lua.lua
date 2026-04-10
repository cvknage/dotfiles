local fzf = function(cmd, opts)
  return function()
    require("fzf-lua")[cmd](opts)
  end
end

return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  keys = {
    { "<leader>,", fzf("buffers"), desc = "Buffer" },
    { "<leader>/", fzf("live_grep"), desc = "Grep" },
    { "<leader>:", fzf("command_history"), desc = "Command History" },
    { "<leader><space>", fzf("files"), desc = "Find files" },

    -- files
    { "<leader>fc", fzf("files", { cwd = vim.fn.stdpath("config") }), desc = "Find Config File" },
    { "<leader>ff", fzf("files"), desc = "Find files" },
    { "<leader>fg", fzf("git_files"), desc = "Find files in Git" },
    { "<leader>fr", fzf("oldfiles", { cwd_only = true }), desc = "Recent (cwd)" },
    { "<leader>fR", fzf("oldfiles"), desc = "Recent" },

    -- git
    { "<leader>gl", fzf("git_commits"), desc = "Logs" },
    { "<leader>gb", fzf("git_branches"), desc = "Branches" },
    { "<leader>gs", fzf("git_status"), desc = "Status" },

    -- search
    { "<leader>sa", fzf("autocmds"), desc = "Auto Commands" },
    { "<leader>sb", fzf("buffers"), desc = "Buffer" },
    { "<leader>sc", fzf("command_history"), desc = "Command History" },
    { "<leader>sC", fzf("commands"), desc = "Commands" },
    { "<leader>sd", fzf("diagnostics_document"), desc = "Document diagnostics" },
    { "<leader>sD", fzf("diagnostics_workspace"), desc = "Workspace diagnostics" },
    { "<leader>sg", fzf("live_grep"), desc = "Grep" },
    { "<leader>sG", fzf("live_grep", { rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden" }), desc = "Grep (hidden)" },
    { "<leader>sh", fzf("helptags"), desc = "Help Pages" },
    { "<leader>sH", fzf("highlights"), desc = "Search Highlight Groups" },
    { "<leader>sk", fzf("keymaps"), desc = "Key Maps" },
    { "<leader>sM", fzf("manpages"), desc = "Man Pages" },
    { "<leader>sm", fzf("marks"), desc = "Jump to Mark" },
    { "<leader>sr", fzf("resume"), desc = "Resume" },
    { "<leader>sR", fzf("registers"), desc = "Registers" },
    { "<leader>sw", fzf("grep_cword"), desc = "Word" },
    { "<leader>ss", fzf("grep_visual"), mode = "v", desc = "Selection" },

    -- ui
    { "<leader>uC", fzf("colorschemes"), desc = "Colorscheme with preview" },

    -- spell
    -- stylua: ignore
    { "z=", function()
      local word = vim.fn.expand("<cword>")
      local suggestions = vim.fn.spellsuggest(word)
      if #suggestions == 0 then
        vim.notify("No suggestions found for: " .. word, vim.log.levels.INFO)
        return
      end
      local choices = {}
      for index, suggestion in ipairs(suggestions) do
        table.insert(choices, {
          display = string.format("%2d: %s", index, suggestion),
          value = suggestion,
        })
      end
      vim.ui.select(choices, {
        prompt = "Replace '" .. word .. "' with:",
        format_item = function(choice) return choice.display end,
      }, function(choice)
        if choice then vim.cmd("normal! ciw" .. choice.value) end
      end)
    end, desc = "Spelling suggestions" },
  },
  opts = {
    "default-title",
    winopts = {
      width = 0.95,
      preview = {
        horizontal = "right:55%",
      },
    },
    fzf_opts = {
      ["--layout"] = "default",
    },
    keymap = {
      builtin = {
        ["<C-f>"] = "preview-page-down",
        ["<C-b>"] = "preview-page-up",
      },
      fzf = {
        ["ctrl-space"] = "toggle",
        ["tab"] = "up",
        ["shift-tab"] = "down",
        ["ctrl-f"] = "preview-page-down",
        ["ctrl-b"] = "preview-page-up",
        ["ctrl-down"] = "next-history",
        ["ctrl-up"] = "prev-history",
      },
    },
  },
  config = function(_, opts)
    local fzf_lua = require("fzf-lua")
    fzf_lua.setup(opts)
    fzf_lua.register_ui_select()
  end,
}
