local M = {}

-- has dotnet installed
M.has_dotnet = vim.fn.executable("dotnet") == 1

function M.test_adapter()
  return require("neotest-dotnet")({
    -- Extra arguments for nvim-dap configuration
    -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
    dap = {
      -- When true debug only user-written code. To debug standard library or anything outside of "cwd" use false. Default is true.
      args = { justMyCode = false },
    },

    -- Let the test-discovery know about your custom attributes (otherwise tests will not be picked up)
    -- Note: Only custom attributes for non-parameterized tests should be added here. See the support note about parameterized tests
    custom_attributes = {
      xunit = { "TestInfo" },
    },

    -- Provide any additional "dotnet test" CLI commands here. These will be applied to ALL test runs performed via neotest. These need to be a table of strings, ideally with one key-value pair per item.
    dotnet_additional_args = {
      "--verbosity detailed",
    },

    -- Tell neotest-dotnet to use either solution (requires .sln file) or project (requires .csproj or .fsproj file) as project root
    -- Note: If neovim is opened from the solution root, using the 'project' setting may sometimes find all nested projects, however,
    --       to locate all test projects in the solution more reliably (if a .sln file is present) then 'solution' is better.
    -- discovery_root = "project" -- Default
    discovery_root = "solution",
  })
end

function M.debug_adapter()
  return {
    adapter = "coreclr",
    dap_options = function(config)
      table.insert(config.configurations, 1, {
        type = "coreclr",
        name = "Attach netcoredbg",
        request = "attach",
        processId = function()
          return require("dap.utils").pick_process({ filter = "dotnet run" })
        end,
      })
      table.insert(config.configurations, 2, {
        type = "coreclr",
        name = "Launch netcoredbg",
        request = "launch",
        program = function()
          if vim.fn.confirm("Should I recompile first?", "&yes\n&no", 2) == 1 then
            M.dotnet_build_project()
          end
          return M.dotnet_get_dll_path()
        end,
      })
      config.configurations[3].name = "Launch dll"

      return config
    end,
  }
end

function M.test_debug_adapter()
  return {
    -- https://github.com/Issafalcon/neotest-dotnet#debugging
    adapter = "netcoredbg",
    config = {
      type = "executable",
      command = vim.fn.exepath("netcoredbg"),
      args = { "--interpreter=vscode" },
    },
  }
end

-- https://github.com/mfussenegger/nvim-dap/wiki/Cookbook#making-debugging-net-easier
function M.dotnet_build_project()
  local default_path = vim.fn.getcwd() .. "/"
  if M["dotnet_last_proj_path"] ~= nil then
    default_path = M["dotnet_last_proj_path"]
  end
  ---@diagnostic disable-next-line: redundant-parameter
  local path = vim.fn.input("Path to your *proj file", default_path, "file")
  M["dotnet_last_proj_path"] = path
  local cmd = "dotnet build -c Debug " .. path .. " > /dev/null"
  print("")
  print("Cmd to execute: " .. cmd)
  local f = os.execute(cmd)
  if f == 0 then
    print("\nBuild: ✔️ ")
  else
    print("\nBuild: ❌ (code: " .. f .. ")")
  end
end

function M.dotnet_get_dll_path()
  local request = function()
    ---@diagnostic disable-next-line: redundant-parameter
    return vim.fn.input("Path to dll", vim.fn.getcwd() .. "/bin/Debug/", "file")
  end

  if M["dotnet_last_dll_path"] == nil then
    M["dotnet_last_dll_path"] = request()
  else
    if vim.fn.confirm("Do you want to change the path to dll?\n" .. M["dotnet_last_dll_path"], "&yes\n&no", 2) == 1 then
      M["dotnet_last_dll_path"] = request()
    end
  end

  return M["dotnet_last_dll_path"]
end

return M
