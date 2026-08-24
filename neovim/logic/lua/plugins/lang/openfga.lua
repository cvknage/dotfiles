return {
  {
    "romus204/tree-sitter-manager.nvim",
    opts = {
      ensure_installed = { "fga" },
      languages = {
        fga = {
          install_info = {
            url = "https://github.com/matoous/tree-sitter-fga",
            revision = "ce72d1c484ba133a18e966d67be66bce85695451",
            -- Required: no bundled runtime/queries/fga to fall back on.
            queries = "queries",
          },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      if vim.fn.executable("fga") ~= 1 then
        return
      end

      opts.linters_by_ft.fga = { "fga" }
      opts.linters.fga = {
        cmd = "fga",
        stdin = false,
        -- Appends the buffer path as the value of --file.
        append_fname = true,
        args = { "model", "validate", "--file" },
        -- An invalid model is a successful run reporting is_valid=false.
        stream = "both",
        ignore_exitcode = true,
        parser = function(output)
          local diagnostics = {}
          if not output or vim.trim(output) == "" then
            return diagnostics
          end

          local ok, decoded = pcall(vim.json.decode, output)
          if ok and type(decoded) == "table" then
            if decoded.is_valid then
              return diagnostics
            end
            output = decoded.error or output
          end

          local function add(lnum, col, message)
            table.insert(diagnostics, {
              lnum = lnum,
              col = col,
              severity = vim.diagnostic.severity.ERROR,
              source = "fga",
              message = vim.trim(message),
            })
          end

          -- Syntax errors carry a position and are joined with "*" bullets; semantic ones do not.
          for lnum, col, message in output:gmatch("line=(%d+), column=(%d+): ([^*]*)") do
            add(math.max(tonumber(lnum) - 1, 0), tonumber(col), message)
          end
          if #diagnostics == 0 then
            add(0, 0, output)
          end

          return diagnostics
        end,
      }
    end,
  },
}
