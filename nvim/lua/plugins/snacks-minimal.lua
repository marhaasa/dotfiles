-- Snacks.nvim config - only statuscolumn and dashboard, disable highlighting features
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
    picker = { enabled = false },
    profiler = { enabled = false },
    scratch = { enabled = false },
    terminal = { enabled = false },
    toggle = { enabled = false },
  },
}