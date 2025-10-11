vim.lsp.config("ltex_plus", {
  on_attach = function()
    require("ltex_extra").setup({
      load_langs = { "da-DK" },
      path = os.getenv("HOME") .. "/.spell/ltex_plus",
    })
  end,
  settings = {
    ltex = {
      -- checkFrequency = "save", -- speed up performance
      language = "da-DK",
      additionalRules = {
        motherTongue = "da-DK",
      },
    },
  },
})

vim.lsp.config("harper_ls", {
  settings = {
    ["harper-ls"] = {
      userDictPath = os.getenv("HOME") .. "/.spell/harper_ls/harper.dictionary.en-US.txt",
    },
  },
})

local M = {}
function M.attach_lsp_to_current_buffer(name)
  -- Get LSP config
  local config = vim.lsp.config[name]
  if not config then
    vim.notify(("No LSP config found for %s"):format(name), vim.log.levels.WARN)
    return false
  end

  local filetype = vim.bo.filetype
  local supported = false

  -- Check if filetype is supported by this server
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

  -- Check if already attached
  for _, client in pairs(vim.lsp.get_clients({ name = name })) do
    if vim.lsp.buf_is_attached(0, client.id) then
      return true
    end
  end

  -- Attach
  vim.lsp.enable(name, true)
  return true
end
function M.detach_lsp_from_current_buffer(name)
  for _, client in pairs(vim.lsp.get_clients({ name = name })) do
    if vim.lsp.buf_is_attached(0, client.id) then
      vim.lsp.buf_detach_client(0, client.id)
    end
  end
end

vim.keymap.set("n", "<leader>ld", function()
  if M.attach_lsp_to_current_buffer("ltex_plus") then
    M.detach_lsp_from_current_buffer("harper_ls")
  end
end, { desc = "Danish Spell" })

vim.keymap.set("n", "<leader>le", function()
  if M.attach_lsp_to_current_buffer("harper_ls") then
    M.detach_lsp_from_current_buffer("ltex_plus")
  end
end, { desc = "English Spell" })

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
        },
      },
    },
  },
}
