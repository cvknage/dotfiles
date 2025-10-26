local M = {}

M.spell_root = os.getenv("HOME") .. "/.spell"
M.vim_spellfile = M.spell_root .. "/nvim"
M.c_spellfile = M.spell_root .. "/cspell_ls"
M.ltex_spellfile = M.spell_root .. "/ltex_plus"
M.harper_spellfile = M.spell_root .. "/harper_ls"

function M.client_is_attached(name)
  for _, client in pairs(vim.lsp.get_clients({ name = name })) do
    if vim.lsp.buf_is_attached(0, client.id) then
      return true
    end
  end
  return false
end

function M.attach_lsp_to_current_buffer(name)
  local config = vim.lsp.config[name]
  if not config then
    vim.notify(("No LSP config found for %s"):format(name), vim.log.levels.WARN)
    return false
  end

  local filetype = vim.bo.filetype
  local supported = false

  if config.filetypes then
    for _, supported_filetype in ipairs(config.filetypes) do
      if supported_filetype == filetype then
        supported = true
        break
      end
    end
  else
    supported = true -- Assume global support if not specified
  end

  if not supported then
    return false
  end

  if M.client_is_attached(name) then
    return true
  end

  -- Start and attach to current buffer only
  local client_id = vim.lsp.start(config)
  if client_id then
    vim.notify(("Attached %s to current buffer"):format(name), vim.log.levels.INFO)
    return true
  else
    vim.notify(("Failed to start %s for current buffer"):format(name), vim.log.levels.ERROR)
    return false
  end
end

function M.detach_lsp_from_current_buffer(name)
  for _, client in pairs(vim.lsp.get_clients({ name = name })) do
    if vim.lsp.buf_is_attached(0, client.id) then
      vim.lsp.buf_detach_client(0, client.id)
    end
  end
end

function M.create_spell_dirs()
  local paths = {
    M.spell_root,
    M.vim_spellfile,
    M.c_spellfile,
    M.ltex_spellfile,
    M.harper_spellfile,
  }
  for _, dir in ipairs(paths) do
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end
end

M.create_spell_dirs()

-- vim.opt.spell = true
vim.opt.spelllang = { "en", "da" }
vim.opt.spellfile = {
  M.vim_spellfile .. "/en.utf-8.add",
  M.vim_spellfile .. "/da.utf-8.add",
}

vim.lsp.config("cspell_ls", {
  cmd = { "cspell-lsp", "--stdio", "--sortWords", "--config", M.c_spellfile .. "/cspell.json" },
  -- stylua: ignore
  filetypes = {
    "bat", "bazel", "c", "clojure", "cmake", "conf", "cpp", "cs", "css", "dart", "dockerfile", "fish", "gitcommit",
    "gitrebase", "go", "gradle", "haskell", "html", "ini", "java", "javascript", "json", "lua", "make", "markdown",
    "md", "nix", "powershell", "properties", "ps1", "python", "ruby", "rust", "scss", "sh", "sql", "swift", "tex",
    "toml", "typescript", "typescriptreact", "typst", "vim", "vimdoc", "xml", "yaml", "yml", "zig",
  },
})

vim.lsp.config("harper_ls", {
  settings = {
    ["harper-ls"] = {
      userDictPath = M.harper_spellfile .. "/harper.dictionary.en-US.txt",
    },
  },
})

vim.lsp.config("ltex_plus", {
  on_attach = function()
    require("ltex_extra").setup({
      load_langs = { "da-DK" },
      path = M.ltex_spellfile,
    })
  end,
  settings = {
    ltex = {
      checkFrequency = "save", -- speed up performance
      language = "da-DK",
      additionalRules = {
        motherTongue = "da-DK",
      },
    },
  },
})

vim.keymap.set("n", "<leader>lV", function()
  local spell_on = vim.wo.spell
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vim.wo[win].spell = not spell_on
  end
end, { desc = "Toggle Vim Spell" })

vim.keymap.set("n", "<leader>lc", function()
  if M.client_is_attached("cspell_ls") then
    M.detach_lsp_from_current_buffer("cspell_ls")
  else
    M.attach_lsp_to_current_buffer("cspell_ls")
  end
end, { desc = "Toggle Code Spell (This Buffer)" })

vim.keymap.set("n", "<leader>lC", function()
  vim.lsp.enable("cspell_ls", not vim.lsp.is_enabled("cspell_ls"))
end, { desc = "Toggle Code Spell" })

vim.keymap.set("n", "<leader>ld", function()
  if M.client_is_attached("ltex_plus") then
    M.detach_lsp_from_current_buffer("ltex_plus")
  else
    M.attach_lsp_to_current_buffer("ltex_plus")
  end
end, { desc = "Toggle Danish Spell (This Buffer)" })

vim.keymap.set("n", "<leader>lD", function()
  vim.lsp.enable("ltex_plus", not vim.lsp.is_enabled("ltex_plus"))
end, { desc = "Toggle Danish Spell" })

vim.keymap.set("n", "<leader>le", function()
  if M.client_is_attached("harper_ls") then
    M.detach_lsp_from_current_buffer("harper_ls")
  else
    M.attach_lsp_to_current_buffer("harper_ls")
  end
end, { desc = "Toggle English Spell (This Buffer)" })

vim.keymap.set("n", "<leader>lE", function()
  vim.lsp.enable("harper_ls", not vim.lsp.is_enabled("harper_ls"))
end, { desc = "Toggle English Spell" })

return {
  {
    "barreiroleo/ltex_extra.nvim",
    lazy = true,
  },
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = {
      ensure_installed = {
        "cspell-lsp",
        "harper-ls",
        "ltex-ls-plus",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    optional = true,
    opts = {
      automatic_enable = {
        exclude = {
          "ltex_plus",
          "harper_ls",
        },
      },
    },
  },
}
