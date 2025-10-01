return {
  -- Completely disable sqls LSP server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqls = false, -- Disable sqls server
      },
      setup = {
        sqls = function()
          -- Return true to prevent default setup
          return true
        end,
      },
    },
  },
  
  -- Ensure mason doesn't try to setup sqls
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.handlers = opts.handlers or {}
      -- Explicitly disable sqls handler with empty function
      opts.handlers.sqls = function() 
        -- Do nothing - prevents sqls from being set up
      end
      return opts
    end,
  },

  -- Override LazyVim's automatic LSP setup for SQL files
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Disable automatic LSP setup for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          -- Prevent LazyVim from setting up any LSP for SQL files
          vim.b.autoformat = false
          -- Clear any LSP clients that might have attached
          local clients = vim.lsp.get_active_clients({ bufnr = 0 })
          for _, client in pairs(clients) do
            if client.name == "sqls" then
              vim.lsp.buf_detach_client(0, client.id)
            end
          end
        end,
      })
      return opts
    end,
  },
}