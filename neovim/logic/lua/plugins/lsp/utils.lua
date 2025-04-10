local M = {}

function M.ensure_installed()
  return { "lua_ls", "ts_ls", "rust_analyzer", "nil_ls" }
end

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

  if client.supports_method("textDocument/inlayHint") then
    -- stylua: ignore
    vim.keymap.set("n", "<leader>ci", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr }) end, options({ desc = "Toggle Inlay Hints" }))
  end
end

function M.inlay_hints(client, bufnr)
  if client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

function M.code_lens(client, bufnr)
  if client.supports_method("textDocument/codeLens") then
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

M.diagnostics = {
  virtual_text = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "✘",
      [vim.diagnostic.severity.WARN] = "▲",
      [vim.diagnostic.severity.HINT] = "⚑",
      [vim.diagnostic.severity.INFO] = "»",
    },
  },
}

function M.lsp_options()
  local options = {}

  options.lua_ls = {
    settings = {
      Lua = {
        telemetry = {
          enable = false,
        },
      },
    },
    on_init = function(client)
      local join = vim.fs.joinpath
      local path = client.workspace_folders[1].name
      local runtime_path = vim.split(package.path, ";")
      table.insert(runtime_path, "lua/?.lua")
      table.insert(runtime_path, "lua/?/init.lua")

      -- Don't do anything if there is project local config
      if vim.uv.fs_stat(join(path, ".luarc.json")) or vim.uv.fs_stat(join(path, ".luarc.jsonc")) then
        return
      end

      local nvim_settings = {
        runtime = {
          -- Tell the language server which version of Lua you're using
          version = "LuaJIT",
          path = runtime_path,
        },
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = { "vim" },
        },
        workspace = {
          checkThirdParty = false,
          library = {
            -- Make the server aware of Neovim runtime files
            vim.env.VIMRUNTIME,
            "${3rd}/luv/library",
            -- "${3rd}/busted/library",
            vim.fn.stdpath("config"),
          },
        },
      }

      client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, nvim_settings)
      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end,
  }

  return options
end

return M
