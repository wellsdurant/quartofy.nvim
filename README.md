# quartofy.nvim

A Neovim plugin that streamlines the workflow of creating Quarto revealjs presentations from markdown files.

## Features

- Automatically detects markdown files with `revealjs` in YAML frontmatter
- Copies files to a working directory (`/tmp/quartofy/`)
- Converts relative image paths to absolute paths
- Processes Zotero citations into IEEE format with arXiv links
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

   Or the alias:
   ```vim
   :QuartofyRevealJS
   ```

3. To stop the preview server:
   ```vim
   :QuartofyStop
   ```

## Controlling the Preview Server

- `:QuartofyStop` - Stop the currently running preview server
  - If tracked by Neovim, stops the job directly
  - Otherwise, attempts to find and kill the process on the configured port
  - Shows a message confirming the action
- **Automatic cleanup**: The preview server is automatically stopped when you exit Neovim

## What It Does

When you run the `:Quartofy` command:

1. **Validates the file**: Checks if the current file is markdown and contains `revealjs` in the YAML frontmatter
2. **Manages file copies**:
   - Creates `/tmp/quartofy/[filename]/` directory
   - Copies the file to `/tmp/quartofy/[filename]/[filename].md`
   - Only overwrites if the current file is newer
3. **Processes Zotero citations**: Converts Zotero links to IEEE format citations with arXiv links
4. **Processes images**: Copies images to target directory and updates paths
5. **Generates Quarto file**: Creates `[filename].qmd` with processed content
6. **Renders**: Runs `quarto render [filename].qmd --to revealjs`
7. **Previews**: Launches `quarto preview` to display the presentation

## Example

Given a file `/home/user/presentations/demo.md`:

```markdown
---
title: Demo
format: revealjs
---

# Title Slide

![Logo](./assets/logo.png)
```

Running `:Quartofy` will:
- Copy to `/tmp/quartofy/demo/demo.md`
- Convert `./assets/logo.png` to `/home/user/presentations/assets/logo.png`
- Generate `/tmp/quartofy/demo/demo.qmd`
- Render and preview the presentation

## Zotero Citation Processing

If you have [zotero-md.nvim](https://github.com/wellsdurant/zotero-md.nvim) installed, Quartofy will automatically process Zotero links in your markdown.

**Requirements:**
- Run `:ZoteroPick` at least once to load citations into cache
- The Zotero item must be in your zotero-md.nvim database

### Inline Citations

**Input:**
```markdown
[GPT2 (2019)](zotero://select/library/items/KCG86VYD)
```

**Output (if has arXiv URL):**
```markdown
[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.](https://arxiv.org/abs/1234.5678)
```

**Output (if no arXiv URL):**
```markdown
A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.
```

### Footnote Citations

**Input:**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[[GPT2 (2019)](zotero://select/library/items/KCG86VYD)]
```

**Output (if has arXiv URL):**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.](https://arxiv.org/abs/1234.5678)]
```

**Output (if no arXiv URL):**
```markdown
OpenAI's GPT-2 (1.5B): fluent text, first signs of zero-shot, staged release ^[A. Radford, J. Wu, R. Child, et al., "Language Models are Unsupervised Multitask Learners", 2019.]
```

The plugin:
- Supports both inline and footnote citation formats
- Converts Zotero links to IEEE citation format
- Creates hyperlinks to arXiv if the paper has an arXiv URL
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
