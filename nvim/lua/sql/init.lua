-- SQL workflow: scratch queries against SQL Server (sqlcmd) or DuckDB, with
-- results in VisiData, schema-aware completion, connection switching, and a
-- statusline indicator.
--
--   connection.lua  backend/credential state, :SqlConn/:SqlDb, statusline
--   runner.lua      query/script execution → VisiData or float
--   explore.lua     history picker, scratch buffers, describe-table float
--   schema.lua      table/column introspection with caching (used by the
--                   blink completion source in blink/cmp/sources/)
--   result.lua      sqlcmd output → CSV re-encoding
--
-- Keymaps live in config/keymaps.lua; setup() registers commands + autocmds.
local connection = require("sql.connection")
local runner = require("sql.runner")
local explore = require("sql.explore")

local M = {}

M.run_query = runner.run_query
M.run_script = runner.run_script
M.open_last_result = runner.open_last_result
M.history_picker = explore.history_picker
M.describe_table = explore.describe_table
M.new_scratch = explore.new_scratch

function M.clear_schema_cache()
  require("sql.schema").clear_cache()
  print("SQL schema cache cleared")
end

function M.schema_cache_status()
  local status = require("sql.schema").get_cache_status()
  print("SQL Cache Status:")
  print("Connection: " .. status.connection)
  print("Tables cached: " .. status.tables_count)
  print("Column sets cached: " .. status.columns_count)
  if status.tables_age then
    print("Tables cache age: " .. status.tables_age .. "s")
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Sql", explore.new_scratch,
    { desc = "Open scratch SQL buffer" })

  -- Switch database mid-session (queries + completion follow, cache resets)
  vim.api.nvim_create_user_command("SqlDb", function(cmd)
    connection.switch_database(cmd.args)
  end, { nargs = 1, desc = "Switch SQL database" })

  -- Switch connection mid-session: 1Password item or local DuckDB file
  vim.api.nvim_create_user_command("SqlConn", function(cmd)
    connection.switch_connection(cmd.args)
  end, {
    nargs = 1,
    complete = connection.op_item_titles,
    desc = "Switch SQL connection (1Password item or DuckDB file)",
  })

  -- Connection indicator in the statusline of SQL buffers
  connection.setup_statusline_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = connection.setup_statusline_hl })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "sql",
    callback = function()
      vim.opt_local.statusline = connection.STATUSLINE
    end,
  })
  -- setup() runs on VeryLazy, after the first file's FileType has fired —
  -- apply directly to any sql windows that already exist
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "sql" then
      vim.wo[win].statusline = connection.STATUSLINE
    end
  end

  -- <C-Space> toggles completion in SQL buffers
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "sql",
    callback = function()
      vim.keymap.set('i', '<C-Space>', function()
        local blink = require('blink.cmp')
        if blink.is_visible() then
          blink.hide()
        else
          blink.show()
        end
      end, { desc = "Toggle SQL completion", buffer = true })
    end,
  })
end

return M
