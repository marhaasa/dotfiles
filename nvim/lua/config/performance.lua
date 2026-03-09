-- Performance optimizations for Neovim
-- Load this early in your config for best results

-- Disable some built-in plugins that slow down startup
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1

-- Faster startup
vim.loader.enable() -- Use Lua loader cache (Neovim 0.9+)

-- Optimize timeouts
vim.opt.timeout = true
vim.opt.timeoutlen = 300  -- Time to wait for mapped sequence (default 1000)
vim.opt.ttimeoutlen = 10  -- Time to wait for key code sequence (default 100)

-- Note: lazyredraw and regexpengine=1 were removed as they cause sluggishness in Neovim

-- Reduce updatetime for better responsiveness
vim.opt.updatetime = 250  -- Default is 4000ms

-- Optimize file reading
vim.opt.synmaxcol = 300   -- Don't syntax highlight very long lines

-- Better memory management
vim.opt.maxmempattern = 1000

-- Disable some expensive features for large files
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function()
    local file_size = vim.fn.getfsize(vim.fn.expand("%"))
    if file_size > 1024 * 1024 then -- 1MB
      -- Disable syntax highlighting and other expensive features for large files
      vim.opt_local.syntax = "off"
      vim.opt_local.wrap = false
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.cursorline = false
      vim.opt_local.cursorcolumn = false
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.spell = false
      print("Large file detected: disabled expensive features for better performance")
    end
  end,
})