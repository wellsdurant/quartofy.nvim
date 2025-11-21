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
