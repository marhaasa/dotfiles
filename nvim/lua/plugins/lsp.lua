return {
  -- Completely disable SQL LSP servers (sqls and sqlls)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqls = false,
        sqlls = false,

        -- markdown-oxide: Obsidian-aware markdown LSP (wikilink completion, gd on [[links]],
        -- backlinks via references, hover, rename with link updates). Installed with Homebrew,
        -- so mason is skipped. Only attaches to files inside the notes vault (~/notes).
        markdown_oxide = {
          mason = false,
          root_dir = function(bufnr, on_dir)
            local notes = vim.uv.fs_realpath(vim.fn.expand("~/notes"))
            local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(bufnr))
            if notes and file and vim.startswith(file, notes .. "/") then
              on_dir(notes)
            end
          end,
          capabilities = {
            workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
          },
        },
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