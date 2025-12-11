return {
  -- Completely disable SQL LSP servers (sqls and sqlls)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqls = false,
        sqlls = false,
      },
      setup = {
        sqls = function()
          return true
        end,
        sqlls = function()
          return true
        end,
      },
    },
  },

  -- Ensure mason doesn't try to setup SQL LSPs
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.handlers = opts.handlers or {}
      opts.handlers.sqls = function() end
      opts.handlers.sqlls = function() end
      return opts
    end,
  },

  -- Override LazyVim's automatic LSP setup for SQL files
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          vim.b.autoformat = false
          local clients = vim.lsp.get_clients({ bufnr = 0 })
          for _, client in pairs(clients) do
            if client.name == "sqls" or client.name == "sqlls" then
              vim.lsp.buf_detach_client(0, client.id)
            end
          end
        end,
      })
      return opts
    end,
  },
}