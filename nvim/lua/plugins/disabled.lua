return {
  -- Core UI plugins to disable
  { "folke/noice.nvim", enabled = false },
  { "rcarriga/nvim-notify", enabled = false },
  { "nvim-lualine/lualine.nvim", enabled = false },
  
  -- Disable ALL mini.nvim modules (prevents horizontal highlights)
  { "nvim-mini/mini.nvim", enabled = false },
  
  -- Disable plugins that cause horizontal highlights
  { "lukas-reineke/indent-blankline.nvim", enabled = false },
  { "RRethy/vim-illuminate", enabled = false },
  -- flash.nvim re-enabled for fast navigation (s/S to jump anywhere)
}
