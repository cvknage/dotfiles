local M = {}

function M.neotest_vstest_adapter()
  -- NOTE: This should be set before calling require("neotest-vstest")
  --- @type neotest_vstest.Config
  vim.g.neotest_vstest = {
    -- Path to dotnet sdk path.
    -- Used in cases where the sdk path cannot be auto discovered.
    --[[
    sdk_path = "/usr/local/dotnet/sdk/9.0.101/",
    ]]

    -- table is passed directly to DAP when debugging tests.
    dap_settings = {
      type = "coreclr",
    },
    -- If multiple solutions exists the adapter will ask you to choose one.
    -- If you have a different heuristic for choosing a solution you can provide a function here.
    solution_selector = function(solutions)
      return nil -- return the solution you want to use or nil to let the adapter choose.
    end,
    -- If multiple .runsettings/testconfig.json files are present in the test project directory
    -- you will be given the choice of file to use when setting up the adapter.
    -- Or you can provide a function here
    -- default nil to select from all files in project directory
    settings_selector = function(project_dir)
      return nil -- return the .runsettings/testconfig.json file you want to use or let the adapter choose
    end,
    build_opts = {
      -- Arguments that will be added to all `dotnet build` and `dotnet msbuild` commands
      additional_args = {},
    },
    -- If project contains directories which are not supposed to be searched for solution files
    discovery_directory_filter = function(search_path)
      -- ignore hidden directories
      return search_path:match("/%.")
    end,
    timeout_ms = 30 * 5 * 1000, -- number of milliseconds to wait before timeout while communicating with adapter client
  }
  return require("neotest-vstest")
end

return M
