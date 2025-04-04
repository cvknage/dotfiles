local utils = require("plugins.lang.dotnet-utils")

return {
  "Exafunction/codeium.vim",
  build = ":Codeium Auth",
  event = "BufEnter",
  enabled = not utils.has_dotnet,
  config = function ()
    vim.g.codeium_disable_bindings = 1
    vim.g.codeium_enabled = true
    vim.g.codeium_manual = true

    vim.keymap.set("i", "<C-a>", function() return vim.fn["codeium#Complete"]() end, { expr = true, silent = true })
    vim.keymap.set("i", "<C-e>", function() return vim.fn["codeium#Clear"]() end, { expr = true, silent = true })
    vim.keymap.set("i", "<C-y>", function () return vim.fn["codeium#Accept"]() end, { expr = true, silent = true })
    vim.keymap.set("i", "<C-TAB>", function() return vim.fn["codeium#CycleCompletions"](1) end, { expr = true, silent = true })
    vim.keymap.set("i", "<C-S-TAB>", function() return vim.fn["codeium#CycleCompletions"](-1) end, { expr = true, silent = true })
  end,
}
