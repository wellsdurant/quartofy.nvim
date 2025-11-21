local M = {}

-- Default configuration
M.config = {
  default_keybinding = true,  -- Set to false to disable <Leader>nr keybinding
}

-- Setup function for user configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Helper function to check if file exists
local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Helper function to get file modification time
local function get_mtime(path)
  local handle = io.popen("stat -f %m " .. vim.fn.shellescape(path) .. " 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return tonumber(result)
end

-- Helper function to parse YAML frontmatter
local function parse_frontmatter()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Check if file starts with ---
  if not lines[1] or lines[1] ~= "---" then
    return nil
  end

  -- Find the closing ---
  local end_idx = nil
  for i = 2, #lines do
    if lines[i] == "---" then
      end_idx = i
      break
    end
  end

  if not end_idx then
    return nil
  end

  -- Check if frontmatter contains "revealjs"
  for i = 2, end_idx - 1 do
    if lines[i]:match("revealjs") then
      return true
    end
  end

  return false
end

-- Helper function to get absolute path of current file directory
local function get_current_file_dir()
  local current_file = vim.fn.expand("%:p")
  return vim.fn.fnamemodify(current_file, ":h")
end

-- Helper function to process image links
local function process_images(content, source_dir)
  local processed = {}

  for _, line in ipairs(content) do
    -- Match markdown image syntax: ![alt](path)
    local modified_line = line:gsub("!%[(.-)%]%((.-)%)", function(alt, path)
      -- Skip if already absolute path or URL
      if path:match("^/") or path:match("^https?://") then
        return "![" .. alt .. "](" .. path .. ")"
      end

      -- Convert relative path to absolute
      local abs_path = source_dir .. "/" .. path
      -- Normalize the path
      abs_path = vim.fn.simplify(abs_path)

      return "![" .. alt .. "](" .. abs_path .. ")"
    end)

    table.insert(processed, modified_line)
  end

  return processed
end

-- Main function to process the file
function M.process()
  -- Check if current buffer is a markdown file
  local filetype = vim.bo.filetype
  if filetype ~= "markdown" then
    vim.notify("Current file is not a markdown file", vim.log.levels.WARN)
    return
  end

  -- Check for revealjs in frontmatter
  local has_revealjs = parse_frontmatter()
  if not has_revealjs then
    vim.notify("File does not contain 'revealjs' in YAML frontmatter", vim.log.levels.WARN)
    return
  end

  -- Get current file info
  local current_file = vim.fn.expand("%:p")
  local filename = vim.fn.expand("%:t:r")  -- filename without extension
  local source_dir = get_current_file_dir()

  -- Create target directory
  local target_dir = "/tmp/quartofy/" .. filename
  local target_md = target_dir .. "/" .. filename .. ".md"
  local target_qmd = target_dir .. "/" .. filename .. ".qmd"

  -- Check if we need to copy the file
  local should_copy = true
  if file_exists(target_md) then
    local current_mtime = get_mtime(current_file)
    local target_mtime = get_mtime(target_md)

    if current_mtime and target_mtime and current_mtime <= target_mtime then
      should_copy = false
    end
  end

  -- Create directory if it doesn't exist
  vim.fn.mkdir(target_dir, "p")

  -- Copy file if needed
  if should_copy then
    vim.notify("Copying file to " .. target_md, vim.log.levels.INFO)
    local copy_cmd = string.format("cp %s %s",
      vim.fn.shellescape(current_file),
      vim.fn.shellescape(target_md))
    os.execute(copy_cmd)
  else
    vim.notify("Using existing file (not older)", vim.log.levels.INFO)
  end

  -- Read the markdown file
  local file = io.open(target_md, "r")
  if not file then
    vim.notify("Failed to read " .. target_md, vim.log.levels.ERROR)
    return
  end

  local content = {}
  for line in file:lines() do
    table.insert(content, line)
  end
  file:close()

  -- Process image links
  vim.notify("Processing image links...", vim.log.levels.INFO)
  local processed_content = process_images(content, source_dir)

  -- Write processed content to .qmd file
  local qmd_file = io.open(target_qmd, "w")
  if not qmd_file then
    vim.notify("Failed to create " .. target_qmd, vim.log.levels.ERROR)
    return
  end

  for _, line in ipairs(processed_content) do
    qmd_file:write(line .. "\n")
  end
  qmd_file:close()

  vim.notify("Generated " .. target_qmd, vim.log.levels.INFO)

  -- Render with Quarto
  vim.notify("Rendering with Quarto...", vim.log.levels.INFO)
  local render_cmd = string.format(
    "cd %s && quarto render %s --to revealjs",
    vim.fn.shellescape(target_dir),
    vim.fn.shellescape(filename .. ".qmd")
  )

  local render_result = os.execute(render_cmd)
  if render_result ~= 0 then
    vim.notify("Quarto render failed", vim.log.levels.ERROR)
    return
  end

  vim.notify("Render complete! Starting preview...", vim.log.levels.INFO)

  -- Preview with Quarto (async)
  local preview_cmd = string.format(
    "cd %s && quarto preview %s",
    vim.fn.shellescape(target_dir),
    vim.fn.shellescape(filename .. ".qmd")
  )

  -- Run preview in background
  vim.fn.jobstart(preview_cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.notify(line, vim.log.levels.INFO)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.notify(line, vim.log.levels.WARN)
          end
        end
      end
    end,
  })
end

return M
