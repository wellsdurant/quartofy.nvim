local M = {}

-- Default configuration
M.config = {
  default_keybinding = true,  -- Set to false to disable <Leader>nr keybinding
  preview_port = 4200,        -- Default port for quarto preview
}

-- Store the preview job ID
M.preview_job_id = nil

-- Setup function for user configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Function to stop the preview server
function M.stop_preview()
  if M.preview_job_id then
    vim.fn.jobstop(M.preview_job_id)
    M.preview_job_id = nil
    echo_msg("Quartofy: Preview stopped")
  else
    -- Try to kill by port
    local kill_cmd = string.format("lsof -ti:%d | xargs kill -9 2>/dev/null", M.config.preview_port)
    vim.fn.jobstart(kill_cmd, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.schedule(function()
            echo_msg("Quartofy: Preview stopped (killed by port)")
          end)
        else
          vim.schedule(function()
            echo_msg("Quartofy: No preview server running on port " .. M.config.preview_port)
          end)
        end
      end,
    })
  end
end

-- Helper function to display message without requiring Enter
local function echo_msg(msg)
  vim.api.nvim_echo({{msg, "Normal"}}, false, {})
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

-- Helper function to sanitize filename for safe filesystem usage
local function sanitize_filename(filename)
  -- Replace spaces with underscores
  local sanitized = filename:gsub(" ", "_")
  -- Remove or replace special characters
  sanitized = sanitized:gsub("[^%w_%-]", "_")
  -- Remove consecutive underscores
  sanitized = sanitized:gsub("_+", "_")
  -- Remove leading/trailing underscores
  sanitized = sanitized:gsub("^_+", ""):gsub("_+$", "")
  return sanitized
end

-- Helper function to get citation from zotero-md.nvim
local function get_zotero_citation(item_id)
  -- Try to load zotero-md.nvim
  local ok, zotero = pcall(require, "zotero-md")
  if not ok or not zotero then
    vim.schedule(function()
      vim.notify("Quartofy: zotero-md.nvim not found or failed to load", vim.log.levels.WARN)
    end)
    return nil
  end

  -- Try to access the cache module
  local cache_ok, cache = pcall(require, "zotero-md.cache")
  if not cache_ok or not cache then
    vim.schedule(function()
      vim.notify("Quartofy: zotero-md.cache module not found", vim.log.levels.WARN)
    end)
    return nil
  end

  -- Get cached references
  local references = cache.get_references()
  if not references or type(references) ~= "table" then
    vim.schedule(function()
      vim.notify("Quartofy: No cached references available. Please run :ZoteroPick first to load the database.", vim.log.levels.WARN)
    end)
    return nil
  end

  -- Find the reference with matching itemKey
  for _, ref in ipairs(references) do
    if ref.itemKey == item_id then
      vim.schedule(function()
        vim.notify("Quartofy: Successfully found citation for ID: " .. item_id, vim.log.levels.INFO)
      end)
      return ref
    end
  end

  vim.schedule(function()
    vim.notify("Quartofy: Citation not found for ID: " .. item_id .. ". Item may not be in the cached database.", vim.log.levels.WARN)
  end)
  return nil
end

-- Helper function to format citation in IEEE style
local function format_ieee_citation(citation)
  if not citation or type(citation) ~= "table" then
    return nil
  end

  local parts = {}

  -- Authors - zotero-md.nvim provides authors as a formatted string
  if citation.authors and citation.authors ~= "" then
    table.insert(parts, citation.authors)
  end

  -- Title
  if citation.title and citation.title ~= "" then
    table.insert(parts, '"' .. citation.title .. '"')
  end

  -- Publication
  if citation.publication and citation.publication ~= "" then
    table.insert(parts, "*" .. citation.publication .. "*")
  end

  -- Year
  if citation.year and citation.year ~= "" then
    table.insert(parts, tostring(citation.year))
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, ", ") .. "."
end

-- Helper function to process a single Zotero citation
local function process_single_zotero_citation(text, item_id)
  local citation = get_zotero_citation(item_id)

  if not citation then
    -- Keep original if citation not found
    return nil
  end

  local ieee_text = format_ieee_citation(citation)
  if not ieee_text then
    return nil
  end

  -- Check for arXiv URL
  if citation.url and citation.url:match("arxiv%.org") then
    return "[" .. ieee_text .. "](" .. citation.url .. ")"
  else
    return ieee_text
  end
end

-- Helper function to process Zotero links
local function process_zotero_links(content)
  local processed = {}

  for _, line in ipairs(content) do
    local modified_line = line
    local has_footnote = line:match("%^%[%[.-%]%(zotero://select/library/items/")

    -- First, handle footnote format: ^[[text](zotero://select/library/items/ITEMID)]
    -- Use non-greedy matching for the text portion
    if has_footnote then
      modified_line = modified_line:gsub("%^%[%[(.-)%]%(zotero://select/library/items/([^%)]+)%)%]", function(text, item_id)
        vim.schedule(function()
          vim.notify("Quartofy: Found footnote citation - text: '" .. text .. "', ID: " .. item_id, vim.log.levels.INFO)
        end)

        local result = process_single_zotero_citation(text, item_id)
        if result then
          vim.schedule(function()
            vim.notify("Quartofy: Successfully processed citation", vim.log.levels.INFO)
          end)
          return "^[" .. result .. "]"
        else
          vim.schedule(function()
            vim.notify("Quartofy: Failed to get citation data for ID: " .. item_id, vim.log.levels.WARN)
          end)
          -- Keep original if processing failed
          return "^[[" .. text .. "](zotero://select/library/items/" .. item_id .. ")]"
        end
      end)
    else
      -- Only process inline format if there's no footnote on this line
      -- This prevents matching inside footnote structures
      modified_line = modified_line:gsub("%[([^%]]+)%]%(zotero://select/library/items/([^%)]+)%)", function(text, item_id)
        vim.schedule(function()
          vim.notify("Quartofy: Found inline citation - text: '" .. text .. "', ID: " .. item_id, vim.log.levels.INFO)
        end)

        local result = process_single_zotero_citation(text, item_id)
        if result then
          return result
        else
          -- Keep original if processing failed
          return "[" .. text .. "](zotero://select/library/items/" .. item_id .. ")"
        end
      end)
    end

    table.insert(processed, modified_line)
  end

  return processed
end

-- Helper function to process image links and copy images
local function process_images(content, source_dir, target_dir)
  local processed = {}

  for _, line in ipairs(content) do
    -- Match markdown image syntax: ![alt](path)
    local modified_line = line:gsub("!%[(.-)%]%((.-)%)", function(alt, path)
      -- Skip if URL
      if path:match("^https?://") then
        return "![" .. alt .. "](" .. path .. ")"
      end

      -- Handle absolute or relative path
      local source_path
      if path:match("^/") then
        source_path = path
      else
        source_path = source_dir .. "/" .. path
        source_path = vim.fn.simplify(source_path)
      end

      -- Check if source image exists
      if not file_exists(source_path) then
        -- Keep original path if file doesn't exist
        return "![" .. alt .. "](" .. path .. ")"
      end

      -- Get filename and copy to target directory
      local filename = vim.fn.fnamemodify(source_path, ":t")
      local target_path = target_dir .. "/" .. filename

      -- Copy image file
      local copy_cmd = string.format("cp %s %s",
        vim.fn.shellescape(source_path),
        vim.fn.shellescape(target_path))
      os.execute(copy_cmd)

      -- Return with just the filename (relative to .qmd file)
      return "![" .. alt .. "](" .. filename .. ")"
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

  -- Sanitize filename for safe filesystem usage
  filename = sanitize_filename(filename)

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

  -- Only process file if it has been updated
  if should_copy then
    -- Copy file
    echo_msg("Quartofy: Copying markdown file...")
    local copy_cmd = string.format("cp %s %s",
      vim.fn.shellescape(current_file),
      vim.fn.shellescape(target_md))
    os.execute(copy_cmd)

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

    -- Process Zotero citations
    echo_msg("Quartofy: Processing Zotero citations...")
    content = process_zotero_links(content)

    -- Process image links and copy images
    echo_msg("Quartofy: Processing images...")
    local processed_content = process_images(content, source_dir, target_dir)

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

    echo_msg("Quartofy: Generating .qmd file complete")
  else
    echo_msg("Quartofy: Markdown file not updated, using existing .qmd")
  end

  -- Render with Quarto using jobstart for better integration
  echo_msg("Quartofy: Rendering with Quarto...")
  local render_cmd = string.format(
    "cd %s && quarto render %s --to revealjs --execute-dir %s",
    vim.fn.shellescape(target_dir),
    vim.fn.shellescape(target_qmd),
    vim.fn.shellescape(target_dir)
  )

  -- Capture output for error reporting
  local stdout_data = {}
  local stderr_data = {}

  -- Run render asynchronously (non-blocking)
  vim.fn.jobstart(render_cmd, {
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.schedule(function()
          echo_msg("Quartofy: Render complete! Starting preview...")
        end)

        -- Start preview after successful render
        local preview_cmd = string.format(
          "cd %s && quarto preview %s --port %d --no-watch-inputs >/dev/null 2>&1",
          vim.fn.shellescape(target_dir),
          vim.fn.shellescape(target_qmd),
          M.config.preview_port
        )

        -- Store the preview job ID for later control
        M.preview_job_id = vim.fn.jobstart(preview_cmd, {
          detach = true,
          on_exit = function()
            M.preview_job_id = nil
            vim.schedule(function()
              echo_msg("Quartofy: Preview stopped")
            end)
          end,
        })

        -- Notify user that command is done
        vim.defer_fn(function()
          echo_msg("Quartofy: Done! Preview running on port " .. M.config.preview_port .. " (use :QuartofyStop to stop)")
        end, 1000)
      else
        vim.schedule(function()
          -- Display error details
          local error_msg = "Quartofy: Render failed\n"
          if #stderr_data > 0 then
            error_msg = error_msg .. "Error: " .. table.concat(stderr_data, "\n")
          end
          vim.notify(error_msg, vim.log.levels.ERROR)
        end)
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

return M
