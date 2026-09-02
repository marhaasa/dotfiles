-- nvim-treesitter (main branch, Neovim 0.12) is set up by LazyVim; only extend its opts here.
-- The main branch has no `nvim-treesitter.configs` module, no `auto_install`, and no
-- highlight/indent modules. LazyVim starts highlighting per FileType and installs any
-- parser listed in `ensure_installed` (lists are merged across specs).
-- The large-file guard lives in lua/config/performance.lua.
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "bash",
      "go",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "typescript",
      "yaml",
      -- "sql" is deliberately absent: the generic parser does not understand T-SQL.
    },
    -- Keep regex syntax for SQL even if a parser gets installed by another spec.
    highlight = { disable = { "sql" } },
    -- Match previous behaviour: treesitter indent and folds stay off (options.lua uses manual folds).
    indent = { enable = false },
    folds = { enable = false },
  },
}
