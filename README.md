# quartofy.nvim

A Neovim plugin that streamlines the workflow of creating Quarto revealjs presentations from markdown files.

## Features

- Automatically detects markdown files with `revealjs` in YAML frontmatter
- Copies files to a working directory (`/tmp/quartofy/`)
- Converts relative image paths to absolute paths
- Processes Zotero citations into IEEE format with hyperlinks
- Renders presentations using Quarto
- Launches preview automatically

## Requirements

- Neovim >= 0.7.0
- [Quarto](https://quarto.org/) installed and available in PATH
- [zotero-md.nvim](https://github.com/wellsdurant/zotero-md.nvim) (optional, for Zotero citation processing)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "wellsdurant/quartofy.nvim",
  dependencies = {
    "wellsdurant/zotero-md.nvim", -- Optional: for Zotero citation processing
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "wellsdurant/quartofy.nvim",
  requires = {
    "wellsdurant/zotero-md.nvim", -- Optional: for Zotero citation processing
  },
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'wellsdurant/zotero-md.nvim'  " Optional: for Zotero citation processing
Plug 'wellsdurant/quartofy.nvim'
```

## Usage

1. Create a markdown file with `revealjs` in the YAML frontmatter:

```markdown
---
title: My Presentation
format: revealjs
---

# Slide 1

Content here

![Image](./images/example.png)
```

2. Open the file in Neovim and press `<Leader>nr` (default keybinding)

   Or use the command:
   ```vim
   :Quartofy
   ```

   The preview will open in your browser and auto-update on every save.

3. Make changes to your markdown file and save (`:w`)

   The preview automatically updates with your changes!

4. To stop the preview server:
   ```vim
   :QuartofyStop
   ```

5. To update installed templates:
   ```vim
   :QuartofyUpdateTemplates
   ```

6. For debugging (to see detailed processing information):
   ```vim
   :QuartofyDebug
   ```

## Controlling the Preview Server

- `:QuartofyStop` - Stop the currently running preview server
  - If tracked by Neovim, stops the job directly
  - Otherwise, attempts to find and kill the process on the configured port
  - Shows a message confirming the action
- **Automatic cleanup**: The preview server is automatically stopped when you exit Neovim
- **Smart reuse**: When rendering the same file multiple times, the preview server is reused instead of being restarted
  - This keeps your browser tab open and just refreshes the content
  - Switching to a different file will stop the old preview and start a new one
- **Auto-update on save**: When a preview is running, the plugin automatically watches for changes to your markdown file
  - Every time you save the file (`:w`), it automatically processes and updates the preview
  - No need to manually run `:Quartofy` again - just save and the preview refreshes

## Managing Templates

- `:QuartofyUpdateTemplates` - Update all installed templates
  - Fetches latest changes from GitHub repositories
  - Updates templates that are behind their remote branches
  - Shows summary of updated templates
- **Automatic installation**: Templates are automatically cloned on first use
- Templates are stored in: `~/.local/share/nvim/quartofy/templates/` (or your configured data directory)

## Debugging

If you encounter issues with citation processing or want to see detailed information about what the plugin is doing:

```vim
:QuartofyDebug
```

This command runs the same process as `:Quartofy` but with verbose debug output showing:
- Citation detection and processing steps
- URL detection and hyperlink creation
- Line modifications and content transformations
- File writing operations

Use this when troubleshooting citation conversion issues or reporting bugs.

## What It Does

When you run the `:Quartofy` command:

1. **Validates the file**: Checks if the current file is markdown and contains `revealjs` in the YAML frontmatter
2. **Manages file copies**:
   - Creates `/tmp/quartofy/[filename]/` directory
   - Copies the file to `/tmp/quartofy/[filename]/[filename].md`
   - Only overwrites if the current file is newer
3. **Processes Zotero citations**: Converts Zotero links to IEEE format citations with hyperlinks
4. **Processes images**: Copies images to target directory and updates paths
5. **Generates Quarto file**: Creates `[filename].qmd` with processed content
6. **Renders**: Runs `quarto render [filename].qmd --to revealjs`
7. **Previews**: Launches or reuses `quarto preview` to display the presentation
   - If previewing the same file, reuses the existing preview server
   - If previewing a different file, stops the old server and starts a new one
   - Sets up auto-update: watches for file saves and automatically updates the preview

## Zotero Citation Processing

If you have [zotero-md.nvim](https://github.com/wellsdurant/zotero-md.nvim) installed, Quartofy will automatically process Zotero links in your markdown.

**Requirements:**
- zotero-md.nvim must be configured with your Zotero database path
- The Zotero item must be in your Zotero library
- Quartofy will automatically load the Zotero database on first use

### Inline Citations

**Input:**
```markdown
[GPT2 (2019)](zotero://select/library/items/KCG86VYD)
```

**Output (if has URL):**
```markdown
[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.](https://arxiv.org/abs/1234.5678)
```

**Output (if no URL):**
```markdown
A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.
```

### Footnote Citations

**Input:**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[[GPT2 (2019)](zotero://select/library/items/KCG86VYD)]
```

**Output (if has URL):**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.](https://arxiv.org/abs/1234.5678)]
```

**Output (if no URL):**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.]
```

The plugin:
- Supports both inline and footnote citation formats
- Converts Zotero links to IEEE citation format
- Creates hyperlinks if the citation has a valid URL (http:// or https://)
- Falls back to plain text citation if no URL is available
- Keeps original link if citation data cannot be retrieved

## Configuration

The plugin works out of the box with sensible defaults. To customize, call `setup()` in your Neovim config:

```lua
require("quartofy").setup({
  default_keybinding = true,  -- Set to false to disable <Leader>nr keybinding
  preview_port = 4200,        -- Port for quarto preview (default: 4200)
})
```

### Configuration Options

- `default_keybinding` (boolean): Enable/disable the `<Leader>nr` keybinding (default: `true`)
- `preview_port` (number): Port number for Quarto preview server. Using a consistent port prevents opening multiple browser tabs (default: `4200`)

### Disabling the Default Keybinding

If you want to set your own keybinding instead:

```lua
-- For lazy.nvim
{
  "wellsdurant/quartofy.nvim",
  config = function()
    require("quartofy").setup({
      default_keybinding = false,
    })
    -- Set your own keybinding
    vim.keymap.set("n", "<Leader>qr", function()
      require("quartofy").process()
    end, { desc = "Quartofy render" })
  end,
}
```

## Troubleshooting

### "File does not contain 'revealjs' in YAML frontmatter"

Make sure your markdown file has YAML frontmatter (between `---` markers) that includes the word `revealjs`:

```markdown
---
format: revealjs
---
```

### "Quarto render failed"

- Ensure Quarto is installed: `quarto --version`
- Check that your markdown syntax is valid
- Verify that all referenced images exist

## License

MIT

## Contributing

Issues and pull requests are welcome!
