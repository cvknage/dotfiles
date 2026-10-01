local dotnet_utils = require("plugins.lang.dotnet.utils")

local M = {}

-- Runs in a coroutine (nvim-dap resolves config fields like `program` that way), so
-- vim.ui.select can block for a choice instead of needing a typed path. schedule_wrap
-- matters: the builtin (non-fzf-lua) vim.ui.select calls back synchronously, and resuming
-- a still-running coroutine from inside itself fails silently and hangs the launch.
---@param prompt string
---@param items string[]
---@return string? choice, boolean cancelled
local function pick(prompt, items)
  if #items == 0 then
    return nil, false
  end
  if #items == 1 then
    return items[1], false
  end
  local co = coroutine.running()
  vim.ui.select(
    items,
    { prompt = prompt },
    vim.schedule_wrap(function(choice)
      coroutine.resume(co, choice)
    end)
  )
  local choice = coroutine.yield()
  return choice, choice == nil
end

-- Finds *.csproj/*.fsproj under cwd and builds the one you pick.
---@return string? project_path
local function netcoredbg_build_project()
  local path, cancelled = pick("Project to build", vim.fn.glob("**/*.?sproj", false, true))
  if cancelled then
    return nil
  end
  if not path then
    ---@diagnostic disable-next-line: redundant-parameter
    path = vim.fn.input("Path to your *proj file", vim.fn.getcwd() .. "/", "file")
  end
  if path == "" then
    return nil
  end

  local cmd = { "dotnet", "build", "-c", "Debug", path }
  print("")
  print("Cmd to execute: " .. table.concat(cmd, " "))
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    print("\nBuild: ❌ (code: " .. result.code .. ")")
    return nil
  end
  print("\nBuild: ✔️ ")

  return path
end

-- Finds the built dll for a project (…/bin/Debug/**/<name>.dll). Falls back to a typed
-- path if that's ambiguous, empty, or the project wasn't built through the function above.
-- Returns dap.ABORT if a multi-match picker was explicitly cancelled.
---@param project_path? string
---@return string|table dll_path
local function netcoredbg_get_dll_path(project_path)
  if project_path then
    local name = vim.fn.fnamemodify(project_path, ":t:r")
    local dir = vim.fn.fnamemodify(project_path, ":h")
    local dll, cancelled = pick("Dll to debug", vim.fn.glob(dir .. "/bin/Debug/**/" .. name .. ".dll", false, true))
    if cancelled then
      return require("dap").ABORT
    end
    if dll then
      return dll
    end
  end
  ---@diagnostic disable-next-line: redundant-parameter
  return vim.fn.input("Path to dll", vim.fn.getcwd() .. "/bin/Debug/", "file")
end

-- Inserts the old setup's dap.configurations.cs entries into mason-nvim-dap's own coreclr
-- config, reusing its default "launch" entry (renamed from "NetCoreDbg: Launch").
local function netcoredbg_mason_dap_options(config)
  local configs = {
    {
      type = "coreclr",
      name = "Attach to process",
      request = "attach",
      processId = function()
        return require("dap.utils").pick_process({ filter = dotnet_utils.attach_process_filter })
      end,
    },
    {
      type = "coreclr",
      name = "Launch debugger",
      request = "launch",
      program = function()
        local project_path
        if vim.fn.confirm("Should I recompile first?", "&yes\n&no", 2) == 1 then
          project_path = netcoredbg_build_project()
        end
        return netcoredbg_get_dll_path(project_path)
      end,
    },
  }

  for i, cfg in ipairs(configs) do
    table.insert(config.configurations, i, cfg)
  end
  config.configurations[#configs + 1].name = "Launch dll"

  return config
end

function M.coreclr_mason_handler(config)
  require("mason-nvim-dap").default_setup(netcoredbg_mason_dap_options(config))
end

return M
