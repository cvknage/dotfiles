local M = {}

--- Configure global LSP keymaps
function M.global_keymaps()
  -- When the Nvim LSP client starts it sets various default options listed here: https://neovim.io/doc/user/lsp.html#lsp-defaults
  -- These GLOBAL keymaps are created unconditionally when Nvim starts
  vim.keymap.del({ "n", "v" }, "gra")
  vim.keymap.del("n", "gri")
  vim.keymap.del("n", "grn")
  vim.keymap.del("n", "grr")
  vim.keymap.del("n", "grt")
  vim.keymap.del("n", "gO")
  vim.keymap.del("i", "<c-S>")
end

--- Configure LSP keymaps
--- @param client vim.lsp.Client
--- @param bufnr integer
function M.keymaps(client, bufnr)
  local telescope_builtin = function(builtin, opts)
    return function()
      require("telescope.builtin")[builtin](opts)
    end
  end

  local options = function(opts)
    return vim.tbl_extend("force", { buffer = bufnr, remap = false }, opts)
  end

  -- stylua: ignore start
  vim.keymap.set("n", "<leader>cl", "<cmd>LspInfo<cr>", options({ desc = "Lsp Info" }))
  -- vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, options({ desc = "Format" }))
  vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, options({ desc = "Rename" }))
  vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, options({ desc = "Code Action" }))
  vim.keymap.set("n", "<leader>cA", function() vim.lsp.buf.code_action({ context = { only = { "source" }, diagnostics = {} } }) end, options({ desc = "Source Action" }))
  -- vim.keymap.set("n", "gd", vim.lsp.buf.definition, options({ desc = "Goto Definition" }))
  vim.keymap.set("n", "gd", telescope_builtin("lsp_definitions", { reuse_win = true }), options({ desc = "Goto Definition" }))
  -- vim.keymap.set("n", "gr", vim.lsp.buf.references, options({ desc = "References" }))
  vim.keymap.set("n", "gr", telescope_builtin("lsp_references", { reuse_win = true }), options({ desc = "References" }))
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, options({ desc = "Goto Declaration" }))
  -- vim.keymap.set("n", "gI", vim.lsp.buf.implementation, options({ desc = "Goto Implementation" }))
  vim.keymap.set("n", "gI", telescope_builtin("lsp_implementations", { reuse_win = true }), options({ desc = "Goto Implementation" }))
  -- vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, options({ desc = "Goto T[y]pe Definition" }))
  vim.keymap.set("n", "gy", telescope_builtin("lsp_type_definitions", { reuse_win = true }), options({ desc = "Goto T[y]pe Definition" }))
  vim.keymap.set("n", "K", vim.lsp.buf.hover, options({ desc = "Hover" }))
  vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))
  vim.keymap.set("i", "<c-k>", vim.lsp.buf.signature_help, options({ desc = "Signature Help" }))
  -- stylua: ignore end

  if client:supports_method("textDocument/inlayHint") then
    -- stylua: ignore
    vim.keymap.set("n", "<leader>ci", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr }) end, options({ desc = "Toggle Inlay Hints" }))
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
    vim.api.nvim_create_autocmd({
      "BufEnter",
      -- "CursorHold",
      "InsertLeave",
    }, {
      buffer = bufnr,
      callback = function(ev)
        vim.lsp.codelens.refresh({ bufnr = ev.buf })
      end,
    })
    vim.lsp.codelens.refresh({ bufnr = bufnr })
  end
end

--- Configure global diagnostic options
function M.diagnostics()
  vim.diagnostic.config({
    virtual_text = true,
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
        -- M.inlay_hints(client, ev.buf)
        M.code_lens(client, ev.buf)
      end
    end,
  })
end

return M
