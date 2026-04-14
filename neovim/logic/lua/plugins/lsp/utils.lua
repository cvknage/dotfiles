local M = {}

--- Configure global LSP keymaps
function M.global_keymaps()
  -- When the Nvim LSP client starts it sets various default options listed here: https://neovim.io/doc/user/lsp.html#lsp-defaults
  -- These GLOBAL keymaps are created unconditionally when Nvim starts
  vim.keymap.del({ "n", "v" }, "gra") -- code actions
  vim.keymap.del("n", "gri") -- implementations
  vim.keymap.del("n", "grn") -- rename
  vim.keymap.del("n", "grr") -- references
  vim.keymap.del("n", "grt") -- type definition
  vim.keymap.del("n", "grx") -- run codelens
  vim.keymap.del("n", "gO") -- document symbols
  vim.keymap.del("i", "<c-S>") -- signature help
end

--- Configure LSP keymaps
--- @param client vim.lsp.Client
--- @param bufnr integer
function M.keymaps(client, bufnr)
  local plugins = require("lazy.core.config").plugins
  local has_fzf_lua = plugins["fzf-lua"] ~= nil
  local has_telescope = plugins["telescope.nvim"] ~= nil
  local has_conform = plugins["conform.nvim"] ~= nil

  local lsp_picker = function(fzf_cmd, telescope_cmd, opts)
    if has_fzf_lua then
      return function()
        require("fzf-lua")[fzf_cmd](opts)
      end
    elseif has_telescope then
      return function()
        require("telescope.builtin")[telescope_cmd](opts)
      end
    end
    return nil
  end

  local MAP = {}
  function MAP.format(mode, lhs, opts)
    if not has_conform then
      vim.keymap.set(mode, lhs, vim.lsp.buf.format, opts)
    end
  end
  function MAP.definitions(mode, lhs, opts)
    local picker = lsp_picker("lsp_definitions", "lsp_definitions", { reuse_win = true })
    if picker then
      vim.keymap.set(mode, lhs, picker, opts)
    else
      vim.keymap.set(mode, lhs, vim.lsp.buf.definition, opts)
    end
  end
  function MAP.references(mode, lhs, opts)
    local picker = lsp_picker("lsp_references", "lsp_references", { reuse_win = true })
    if picker then
      vim.keymap.set(mode, lhs, picker, opts)
    else
      vim.keymap.set(mode, lhs, vim.lsp.buf.references, opts)
    end
  end
  function MAP.implementation(mode, lhs, opts)
    local picker = lsp_picker("lsp_implementations", "lsp_implementations", { reuse_win = true })
    if picker then
      vim.keymap.set(mode, lhs, picker, opts)
    else
      vim.keymap.set(mode, lhs, vim.lsp.buf.implementation, opts)
    end
  end
  function MAP.type_definition(mode, lhs, opts)
    local picker = lsp_picker("lsp_typedefs", "lsp_type_definitions", { reuse_win = true })
    if picker then
      vim.keymap.set(mode, lhs, picker, opts)
    else
      vim.keymap.set(mode, lhs, vim.lsp.buf.type_definition, opts)
    end
  end

  local options = function(opts)
    return vim.tbl_extend("force", { buffer = bufnr, remap = false }, opts)
  end

  vim.keymap.set("n", "<leader>cl", "<cmd>LspInfo<cr>", options({ desc = "Lsp Info" }))
  MAP.format("n", "<leader>cf", options({ desc = "Format" }))
  vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, options({ desc = "Rename" }))
  vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, options({ desc = "Code Action" }))
  vim.keymap.set("n", "<leader>cA", function()
    vim.lsp.buf.code_action({ context = { only = { "source" }, diagnostics = {} } })
  end, options({ desc = "Source Action" }))
  MAP.definitions("n", "gd", options({ desc = "Goto Definition" }))
  MAP.references("n", "gr", options({ desc = "References" }))
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, options({ desc = "Goto Declaration" }))
  MAP.implementation("n", "gI", options({ desc = "Goto Implementation" }))
  MAP.type_definition("n", "gy", options({ desc = "Goto T[y]pe Definition" }))
  vim.keymap.set("n", "K", vim.lsp.buf.hover, options({ desc = "Hover" }))
  vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))
  vim.keymap.set("i", "<c-k>", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))

  if client:supports_method("textDocument/inlayHint") then
    vim.keymap.set("n", "<leader>ci", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
    end, options({ desc = "Toggle Inlay Hints" }))
  end
end

--- Enable inlay hints on supported clients
--- @param client vim.lsp.Client
--- @param bufnr integer
function M.inlay_hints(client, bufnr)
  if client:supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

--- Enable code lens on supported clients
--- @param client vim.lsp.Client
--- @param bufnr integer
function M.code_lens(client, bufnr)
  if client:supports_method("textDocument/codeLens") then
    local codelens_update = function(buf)
      pcall(vim.lsp.codelens.enable, true, { bufnr = buf })
    end

    vim.api.nvim_create_autocmd({
      "BufEnter",
      -- "CursorHold",
      "InsertLeave",
    }, {
      buffer = bufnr,
      callback = function(ev)
        codelens_update(ev.buf)
      end,
    })
    codelens_update(bufnr)
  end
end

--- Enable document highlight on supported clients
--- @param client vim.lsp.Client
--- @param bufnr integer
function M.document_highlight(client, bufnr)
  if not client:supports_method("textDocument/documentHighlight") then
    return
  end

  if vim.b[bufnr].lsp_document_highlight then
    return
  end

  vim.b[bufnr].lsp_document_highlight = true

  local highlight_group = vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = highlight_group,
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.document_highlight()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    group = highlight_group,
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.clear_references()
    end,
  })
end

--- Configure global diagnostic options
function M.diagnostics()
  vim.diagnostic.config({
    update_in_insert = true,
    underline = true,
    virtual_text = true,
    virtual_lines = false,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "✘",
        [vim.diagnostic.severity.WARN] = "▲",
        [vim.diagnostic.severity.HINT] = "⚑",
        [vim.diagnostic.severity.INFO] = "»",
      },
    },
  })
end

--- Configure active LSP options
function M.lsp_attach()
  -- LspAttach is where you enable features that only work if there is a language server active in the file
  vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP actions",
    callback = function(ev)
      local clients = vim.lsp.get_clients({ buffer = ev.buf })
      for _, client in pairs(clients) do
        M.keymaps(client, ev.buf)
        M.document_highlight(client, ev.buf)
        -- M.inlay_hints(client, ev.buf)
        M.code_lens(client, ev.buf)
      end
    end,
  })
end

return M
