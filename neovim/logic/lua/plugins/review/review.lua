local utils = require("utils")

local M = {}

M.state = { files = {}, index = 0, tab = nil, base = nil }

local function parse_name_status(lines)
  local entries = {}
  for _, line in ipairs(lines) do
    local status, rest = line:match("^(%a)%S*\t(.*)$")
    if status then
      table.insert(entries, { path = rest:match("([^\t]+)$"), status = status })
    end
  end
  return entries
end

function M.staged_files()
  return parse_name_status(vim.fn.systemlist("git diff --staged --name-status"))
end

function M.pr_files(base)
  return parse_name_status(vim.fn.systemlist("git diff --name-status " .. vim.fn.shellescape(base) .. "...HEAD"))
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
  local is_new = entry.status == "A" or entry.status == "R" -- R: the new path has no version at the base either
  vim.cmd("silent! only")
  vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
  if not vim.bo.modified then
    vim.cmd("edit!")
  end
  if not is_new then
    vim.cmd("vertical Gdiffsplit " .. M.state.base) -- side by side; the right pane is the real file, not an index blob
  end
  -- New-path files get no diff pane: they have no version at the base, and a synthetic
  -- stand-in reliably segfaulted this plugin stack when :only tore it down on the next file.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    M.map_nav(vim.api.nvim_win_get_buf(win))
  end
  local suffix = entry.status == "A" and " (new file)" or entry.status == "R" and " (renamed, no diff)" or ""
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

local function start(base, files)
  if #files == 0 then
    vim.notify("No files to review", vim.log.levels.WARN)
    return
  end
  M.state.base = base
  M.state.files = files
  vim.cmd("tabnew")
  M.state.tab = vim.api.nvim_get_current_tabpage()
  M.state.index = 1
  M.show()
end

function M.toggle()
  if M.close() then
    return
  end
  local staged = M.staged_files()
  if #staged > 0 then
    start("HEAD", staged)
    return
  end
  if not utils.is_work_config then
    vim.notify("No staged files to review", vim.log.levels.WARN)
    return
  end
  local base_branch = vim.trim(vim.fn.system("gh pr view --json baseRefName --jq .baseRefName"))
  if vim.v.shell_error ~= 0 or base_branch == "" then
    vim.notify("No staged files to review, and no PR found for this branch", vim.log.levels.WARN)
    return
  end
  local merge_base = vim.trim(vim.fn.system("git merge-base " .. vim.fn.shellescape(base_branch) .. " HEAD"))
  if vim.v.shell_error ~= 0 or merge_base == "" then
    vim.notify("Could not compute a merge base against " .. base_branch, vim.log.levels.ERROR)
    return
  end
  start(merge_base, M.pr_files(merge_base))
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
