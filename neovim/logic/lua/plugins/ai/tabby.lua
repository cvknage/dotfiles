-- Install Tabby server: https://tabby.tabbyml.com/docs/installation/
-- Configuration instructions  https://tabby.tabbyml.com/docs/getting-started

return {
  "TabbyML/vim-tabby",
  enabled = vim.fn.executable("tabby") == 1,
  event = "BufEnter",
  init = function()
    -- Available models: https://tabby.tabbyml.com/docs/models/

    if vim.loop.os_uname().sysname == "Darwin" then
      pcall(io.popen, "tabby serve --device metal --model TabbyML/StarCoder-3B > /dev/null 2>&1 &")
      -- pcall(io.popen, "tabby serve --device metal --model TabbyML/CodeLlama-7B > /dev/null 2>&1 &")
    else
      --[[
      if vim.fn.executable("docker") ~= 1 then
        pcall(io.popen, "docker run -it -p 8080:8080 -v $HOME/.tabby:/data tabbyml/tabby serve --model TabbyML/StarCoder-3B > /dev/null 2>&1 &")
        -- pcall(io.popen, "docker run -it --gpus all -p 8080:8080 -v $HOME/.tabby:/data tabbyml/tabby serve --model TabbyML/StarCoder-3B --device cuda > /dev/null 2>&1 &")
      end
      --]]
    end
  end,
  config = function()
    vim.g.tabby_keybinding_accept = "<C-y>"
    vim.g.tabby_keybinding_trigger_or_dismiss = "<C-e>"
  end,
}
