local function navigate(wincmd, dir)
  local before = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= before then
    return
  end
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    vim.fn.system({ "herdr", "pane", "focus", "--direction", dir, "--pane", vim.env.HERDR_PANE_ID })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    -- stylua: ignore
    local tmux_commands = { left = "TmuxNavigateLeft", down = "TmuxNavigateDown", up = "TmuxNavigateUp", right = "TmuxNavigateRight" }
    vim.cmd(tmux_commands[dir])
  end
end

return {
  "christoomey/vim-tmux-navigator",
  enabled = vim.fn.executable("tmux") == 1 or vim.fn.executable("herdr") == 1,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  -- stylua: ignore
  keys = {
    {"<C-h>", function() navigate("h", "left") end, desc = "Go to left window"},
    {"<C-j>", function() navigate("j", "down") end, desc = "Go to lower window"},
    {"<C-k>", function() navigate("k", "up") end, desc = "Go to upper window"},
    {"<C-l>", function() navigate("l", "right") end, desc = "Go to right window"},
  },
}

--[[
return {
  "christoomey/vim-tmux-navigator",
  enabled = vim.fn.executable("tmux") == 1,
  keys = {
    { "<C-h>", desc = "Go to left window" },
    { "<C-j>", desc = "Go to lower window" },
    { "<C-k>", desc = "Go to upper window" },
    { "<C-l>", desc = "Go to right window" },
  },
}
]]
