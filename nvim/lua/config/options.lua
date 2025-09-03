-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.ignorecase = true
opt.spell = false
opt.foldmethod = "manual"
opt.foldenable = false

opt.termguicolors = true
-- scrolling
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.linebreak = true

-- Remove command line and other UI elements
opt.cmdheight = 0
opt.fillchars = { eob = " " }
opt.showtabline = 0
opt.laststatus = 2  -- Always show statusline (standard behavior)
opt.ruler = false
opt.showcmd = false

-- Note: Zettelkasten functions and keymaps have been moved to lua/config/keymaps.lua
