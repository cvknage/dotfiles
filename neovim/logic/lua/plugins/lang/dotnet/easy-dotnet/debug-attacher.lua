local dotnet_utils = require("plugins.lang.dotnet.utils")
local config = require("plugins.lang.dotnet.easy-dotnet.config")

local M = {}

-- Private state remembered across calls; declared here rather than springing up ad hoc.
local easy_dotnet_debugger_path = nil

-- Resolves the debugger binary path via `dotnet-easydotnet healthcheck --debugger-engine
-- <engine>`, memoized across calls (false means resolution failed, not "not yet tried").
---@param engine string
---@return string|false path
local function resolve_debugger_path(engine)
  if easy_dotnet_debugger_path ~= nil then
    return easy_dotnet_debugger_path
  end

  easy_dotnet_debugger_path = false
  local output = vim.fn.system({ "dotnet-easydotnet", "healthcheck", "--format", "json", "--debugger-engine", engine })
  if vim.v.shell_error == 0 then
    local ok, health = pcall(vim.json.decode, output)
    if ok and type(health) == "table" then
      for _, check in ipairs(health) do
        if check.name == "debugger.path" and check.type == "ok" then
          easy_dotnet_debugger_path = check.value
          break
        end
      end
    end
  end
  if not easy_dotnet_debugger_path then
    vim.notify("easy-dotnet: failed to resolve " .. engine .. " via dotnet-easydotnet healthcheck", vim.log.levels.WARN)
  end

  return easy_dotnet_debugger_path
end

-- Resolves the dap.adapters entry (registered under "coreclr") for whichever engine
-- easy_dotnet_debugger_engine selects — also what .vscode/launch.json's "coreclr" entries use.
---@return table? adapter
local function easy_dotnet_resolve_adapter()
  local engine = config.easy_dotnet_debugger_engine
  local path = resolve_debugger_path(engine)
  if not path then
    return nil
  end

  -- netcoredbg needs --interpreter=vscode to speak DAP over stdio; dncdbg/sharpdbg need nothing.
  local engine_dap_args = {
    netcoredbg = { "--interpreter=vscode" },
  }

  -- sharpdbg is a managed .dll, launched via `dotnet <dll>` instead of directly.
  local command, args
  if path:match("%.dll$") then
    command = "dotnet"
    args = { path }
    vim.list_extend(args, engine_dap_args[engine] or {})
  else
    command = path
    args = engine_dap_args[engine] or {}
  end

  return { type = "executable", command = command, args = args }
end

-- "Attach to process" using whichever engine easy_dotnet_debugger_engine selects.
---@return table[]
function M.easy_dotnet_attach_config()
  local adapter = easy_dotnet_resolve_adapter()
  if not adapter then
    return {}
  end

  require("dap").adapters.coreclr = adapter

  return {
    {
      type = "coreclr",
      name = "Attach to process",
      request = "attach",
      processId = function()
        return require("dap.utils").pick_process({ filter = dotnet_utils.attach_process_filter })
      end,
    },
  }
end

return M
