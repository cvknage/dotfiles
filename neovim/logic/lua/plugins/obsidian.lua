return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  -- stylua: ignore
  keys = {
    { "<leader>on", "<cmd>ObsidianNew<cr>",         desc = "New Note",        mode = "n" },
    { "<leader>os", "<cmd>ObsidianSearch<cr>",      desc = "Search Notes",    mode = "n" },
    { "<leader>of", "<cmd>ObsidianQuickSwitch<cr>", desc = "Find Notes",      mode = "n" },
    { "<leader>ob", "<cmd>ObsidianBacklinks<cr>",   desc = "Show Backlinks",  mode = "n" },
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>",    desc = "Insert Template", mode = "n" },
  },
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required.
    { "hrsh7th/nvim-cmp", optional = true },
  },
  opts = {
    -- Optional, configure additional syntax highlighting / extmarks.
    -- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
    ui = { enable = false }, -- set to false to disable all additional syntax features

    -- A list of workspace names, paths, and configuration overrides.
    -- If you use the Obsidian app, the 'path' of a workspace should generally be
    -- your vault root (where the `.obsidian` folder is located).
    -- When obsidian.nvim is loaded by your plugin manager, it will automatically set
    -- the workspace to the first workspace in the list whose `path` is a parent of the
    -- current markdown file being edited.
    workspaces = {
      {
        name = "notes",
        path = "~/Notes/notes",
      },
    },

    -- Optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
    completion = {
      -- Set to false to disable completion.
      nvim_cmp = true,
      -- Trigger completion at 2 chars.
      min_chars = 2,
    },

    -- Optional, configure key mappings. These are the defaults. If you don't want to set any keymappings this
    -- way then set 'mappings = {}'.
    mappings = {
      -- Follow markdown/wiki links within your vault "Obsidian follow".
      -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
      ["<leader>og"] = {
        action = function()
          return require("obsidian").util.gf_passthrough()
        end,
        opts = { noremap = false, expr = true, buffer = true, desc = "Go To" },
      },
      -- Toggle check-boxes "Obsidian done".
      ["<leader>oc"] = {
        action = function()
          return require("obsidian").util.toggle_checkbox()
        end,
        opts = { buffer = true, desc = "Toggle Checkbox" },
      },
      -- Smart action depending on context, either follow link or toggle checkbox.
      ["<leader>oa"] = {
        action = function()
          return require("obsidian").util.smart_action()
        end,
        opts = { buffer = true, expr = true, desc = "Smart Action" },
      },
    },

    -- Optional, customize how note IDs are generated given an optional title.
    ---@param title string|?
    ---@return string
    note_id_func = function(title)
      local id = ""
      if title ~= nil then
        id = title
      else
        id = "Untitled-" .. tostring(os.time())
      end
      return id
    end,

    -- Optional, alternatively you can customize the frontmatter data.
    ---@return table
    note_frontmatter_func = function(note)
      -- Add the title of the note as an alias.
      if note.title then
        note:add_alias(note.title)
      end

      local out = { id = note.id, aliases = note.aliases, tags = note.tags, area = "", project = "" }

      -- `note.metadata` contains any manually added fields in the frontmatter.
      -- So here we just make sure those fields are kept in the frontmatter.
      if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
        for k, v in pairs(note.metadata) do
          out[k] = v
        end
      end

      return out
    end,

    -- Optional, for templates (see below).
    templates = {
      folder = "Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      -- A map for custom variables, the key should be the variable and the value a function
      substitutions = {},
    },
  },
  config = function(_, opts)
    local has_cmp = pcall(require, "cmp")
    opts.completion.nvim_cmp = has_cmp
    require("obsidian").setup(opts)
  end,
}
