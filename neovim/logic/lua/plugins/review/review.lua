local M = {}

M.state = { files = {}, index = 0, tab = nil }

function M.staged_files()
  local entries = {}
  for _, line in ipairs(vim.fn.systemlist("git diff --staged --name-status")) do
    local status, rest = line:match("^(%a)%S*\t(.*)$")
    if status then
      table.insert(entries, { path = rest:match("([^\t]+)$"), status = status })
    end
  end
  return entries
end

-- Bound per window shown for this file, not once globally, so C-n/C-p stay scoped here.
function M.map_nav(bufnr)
  vim.keymap.set("n", "<C-n>", function()
    M.step(1)
  end, { buffer = bufnr, desc = "Next Review File" })
  vim.keymap.set("n", "<C-p>", function()
    M.step(-1)
  end, { buffer = bufnr, desc = "Prev Review File" })
end

function M.show()
  local entry = M.state.files[M.state.index]
  vim.cmd("silent! only")
  vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
  if entry.status ~= "A" then
    vim.cmd("vertical Gdiffsplit HEAD") -- side by side; the right pane is the real file, not an index blob
  end
  -- Added files get no diff pane: they have no HEAD version, and a synthetic stand-in
  -- reliably segfaulted this plugin stack when :only tore it down on the next file.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    M.map_nav(vim.api.nvim_win_get_buf(win))
  end
  local suffix = entry.status == "A" and " (new file)" or ""
  vim.notify(string.format("[%d/%d] %s%s", M.state.index, #M.state.files, entry.path, suffix))
end

-- Returns true whenever the situation is handled: either it closed the tab, or there
-- was only one tab and nothing to close.
function M.close()
  if not (M.state.tab and vim.api.nvim_tabpage_is_valid(M.state.tab)) then
    return false
  end
  if vim.fn.tabpagenr("$") == 1 then
    vim.notify("Review tab is the only tab open", vim.log.levels.WARN)
    return true
  end
  vim.cmd(vim.api.nvim_tabpage_get_number(M.state.tab) .. "tabclose")
  M.state.tab = nil
  return true
end

function M.toggle()
  if M.close() then
    return
  end
  M.state.files = M.staged_files()
  if #M.state.files == 0 then
    vim.notify("No staged files to review", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabnew")
  M.state.tab = vim.api.nvim_get_current_tabpage()
  M.state.index = 1
  M.show()
end

function M.step(delta)
  if #M.state.files == 0 then
    M.toggle()
    return
  end
  M.state.index = ((M.state.index - 1 + delta) % #M.state.files) + 1
  M.show()
end

function M.add_comment()
  local commentstring = vim.bo.commentstring ~= "" and vim.bo.commentstring or "# %s"
  local indent = vim.fn.matchstr(vim.fn.getline("."), [[^\s*]])
  local line = indent .. commentstring:format("REVIEW: ")
  vim.fn.append(vim.fn.line("."), line)
  vim.api.nvim_win_set_cursor(0, { vim.fn.line(".") + 1, #line })
  vim.cmd("startinsert!")
end

return M
