return {

  -- Main formatting configuration with conform.nvim
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- Python formatting with black
      opts.formatters_by_ft.python = { "black" }

      -- T-SQL formatting with sqlfluff. Manual only: lsp.lua sets vim.b.autoformat = false for sql,
      -- so format-on-save never runs. The config lives at the dotfiles root (.sqlfluff).
      local dotfiles = vim.env.DOTFILES
        or vim.fs.dirname(vim.uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config"))
      opts.formatters.sqlfluff = {
        command = "sqlfluff",
        args = { "format", "--dialect", "tsql", "--config", dotfiles .. "/.sqlfluff", "-" },
        stdin = true,
      }
      opts.formatters_by_ft.sql = { "sqlfluff" }

      return opts
    end,

    init = function()

      -- Manual formatting keymaps for Python files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          vim.keymap.set("n", "<leader>fmt", function()
            require("conform").format({
              bufnr = vim.api.nvim_get_current_buf(),
              timeout_ms = 3000,
            })
          end, { desc = "Format Python", buffer = true })

          -- Python-specific settings
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.expandtab = true
        end,
      })

      -- Manual T-SQL formatting (sqlfluff). <leader>sf remains the SSDT table formatter.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "sql",
        callback = function()
          vim.keymap.set("n", "<leader>sF", function()
            require("conform").format({
              bufnr = vim.api.nvim_get_current_buf(),
              formatters = { "sqlfluff" },
              timeout_ms = 10000,
            })
          end, { desc = "Format SQL with sqlfluff (T-SQL)", buffer = true })
        end,
      })
    end,
  },
}
