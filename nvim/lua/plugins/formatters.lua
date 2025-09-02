return {

  -- Main formatting configuration with conform.nvim
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}


      -- Python formatting with black
      opts.formatters_by_ft.python = { "black" }

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
    end,
  },
}