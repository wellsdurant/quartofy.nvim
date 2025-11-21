# quartofy.nvim

A Neovim plugin that streamlines the workflow of creating Quarto revealjs presentations from markdown files.

## Features

- Automatically detects markdown files with `revealjs` in YAML frontmatter
- Copies files to a working directory (`/tmp/quartofy/`)
- Converts relative image paths to absolute paths
- Renders presentations using Quarto
- Launches preview automatically

## Requirements

- Neovim >= 0.7.0
- [Quarto](https://quarto.org/) installed and available in PATH

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "wellsdurant/quartofy.nvim",
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use "wellsdurant/quartofy.nvim"
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
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

## What It Does

When you run the `:Quartofy` command:

1. **Validates the file**: Checks if the current file is markdown and contains `revealjs` in the YAML frontmatter
2. **Manages file copies**:
   - Creates `/tmp/quartofy/[filename]/` directory
   - Copies the file to `/tmp/quartofy/[filename]/[filename].md`
   - Only overwrites if the current file is newer
3. **Processes images**: Converts relative image paths to absolute paths in the copy
4. **Generates Quarto file**: Creates `[filename].qmd` with processed content
5. **Renders**: Runs `quarto render [filename].qmd --to revealjs`
6. **Previews**: Launches `quarto preview` to display the presentation

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
