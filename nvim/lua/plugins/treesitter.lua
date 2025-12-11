return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  config = function()
    local ok, configs = pcall(require, "nvim-treesitter.configs")
    if not ok then
      return
    end
    configs.setup({
      -- Only install parsers for languages you actively use
      ensure_installed = {
        "lua",
        "python",
        "javascript",
        "typescript",
        "bash",
        "json",
        "yaml",
        "go",
        -- "sql", -- Disabled: generic SQL parser doesn't support T-SQL/SQL Server
        "markdown",
        "markdown_inline",
      },
      
      -- Install parsers synchronously (only applied to `ensure_installed`)
      sync_install = false,
      
      -- Automatically install missing parsers when entering buffer
      auto_install = true,
      
      highlight = {
        enable = true,
        -- Performance: disable for large files and problematic languages
        disable = function(lang, buf)
          local max_filesize = 100 * 1024 -- 100 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end

          -- Disable for specific cases that cause issues
          local buf_name = vim.fn.expand("%")
          if lang == "terraform" and string.find(buf_name, "fixture") then
            return true
          end

          -- Disable for SQL - the generic parser doesn't support T-SQL/SQL Server syntax
          if lang == "sql" then
            return true
          end
        end,
        
        -- Performance: limit additional highlighting
        additional_vim_regex_highlighting = false,
      },
      
      -- Performance: disable incremental selection (rarely used)
      incremental_selection = { enable = false },
      
      -- Performance: disable indentation (can be slow)
      indent = { enable = false },
    })
  end,
}
