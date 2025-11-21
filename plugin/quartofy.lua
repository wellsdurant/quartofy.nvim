-- Prevent loading the plugin twice
if vim.g.loaded_quartofy then
  return
end
vim.g.loaded_quartofy = true

-- Create the command
vim.api.nvim_create_user_command("Quartofy", function()
  require("quartofy").process()
end, {
  desc = "Process markdown file for Quarto revealjs presentation"
})

-- Optional: Create an alias
vim.api.nvim_create_user_command("QuartofyRevealJS", function()
  require("quartofy").process()
end, {
  desc = "Process markdown file for Quarto revealjs presentation"
})

-- Command to run with debug output
vim.api.nvim_create_user_command("QuartofyDebug", function()
  require("quartofy").process_debug()
end, {
  desc = "Process markdown file with verbose debug output"
})

-- Command to stop the preview server
vim.api.nvim_create_user_command("QuartofyStop", function()
  require("quartofy").stop_preview()
end, {
  desc = "Stop the Quartofy preview server"
})

-- Automatically stop preview server when Neovim exits
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    require("quartofy").stop_preview()
  end,
  desc = "Stop Quartofy preview server on exit"
})

-- Default keybinding (can be disabled via setup)
local function setup_default_keybinding()
  local quartofy = require("quartofy")
  if quartofy.config.default_keybinding then
    vim.keymap.set("n", "<Leader>nr", function()
      quartofy.process()
    end, {
      desc = "Quartofy: Render and preview revealjs presentation",
      silent = true
    })
  end
end

-- Set up default keybinding after a short delay to allow user config to load
vim.defer_fn(setup_default_keybinding, 0)
