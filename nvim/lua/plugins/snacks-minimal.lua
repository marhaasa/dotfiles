-- Snacks.nvim config - statuscolumn, dashboard, explorer; highlighting features disabled
return {
  "folke/snacks.nvim",
  opts = {
    -- Essential functionality
    statuscolumn = { enabled = true }, -- Required by LazyVim
    dashboard = { enabled = true },     -- Entry screen
    
    -- Useful features
    quickfile = { enabled = true },     -- Faster file opening
    bigfile = { enabled = true },       -- Graceful large file handling
    rename = { enabled = true },        -- LSP-aware file renaming
    image = { enabled = true },         -- Inline image preview (markdown) in Ghostty/kitty
    explorer = { enabled = true, replace_netrw = true }, -- File explorer (<leader>e), LazyVim's current default

    -- Disable visual noise
    scroll = { enabled = false },
    words = { enabled = false },
    animate = { enabled = false },
    indent = { enabled = false },
    scope = { enabled = false },

    -- Other features (keep disabled)
    notifier = { enabled = false },
    zen = { enabled = false },
    bufdelete = { enabled = false },
    debug = { enabled = false },
    git = { enabled = false },
    gitbrowse = { enabled = false },
    lazygit = { enabled = false },
    -- The explorer is a picker in disguise, so the picker module must be on.
    -- LazyVim's search/LSP keymaps still use Telescope (vim.g.lazyvim_picker).
    picker = {
      enabled = true,
      ui_select = false, -- leave vim.ui.select to Telescope
      sources = {
        explorer = {
          diagnostics = false, -- same as the old neo-tree override
        },
      },
    },
    profiler = { enabled = false },
    scratch = { enabled = false },
    terminal = { enabled = false },
    toggle = { enabled = false },
  },
}