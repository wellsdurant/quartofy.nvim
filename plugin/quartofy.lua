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

-- Command to update templates
vim.api.nvim_create_user_command("QuartofyUpdateTemplates", function()
  require("quartofy").update_templates()
end, {
  desc = "Update all installed Quartofy templates"
})

-- Command to show configuration
vim.api.nvim_create_user_command("QuartofyConfig", function()
  local quartofy = require("quartofy")
  local config_lines = {
    "Quartofy Configuration:",
    "  default_keybinding: " .. tostring(quartofy.config.default_keybinding),
    "  preview_port: " .. tostring(quartofy.config.preview_port),
    "  vault_path: " .. (quartofy.config.vault_path or "nil (not set)"),
  }
  vim.notify(table.concat(config_lines, "\n"), vim.log.levels.INFO)
end, {
  desc = "Show Quartofy configuration"
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
