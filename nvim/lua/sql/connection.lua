-- Connection state for the SQL workflow: which backend is active (SQL Server
-- via sqlcmd, or a local DuckDB file set by the `sql` shell function), the
-- credentials/database for it, and the statusline segment showing it.
local M = {}

-- Returns "duckdb", <path>  or  "sqlserver"
function M.backend()
  local duckdb = os.getenv("DUCKDB")
  if duckdb and duckdb ~= "" then
    return "duckdb", duckdb
  end
  return "sqlserver"
end

function M.server()
  return os.getenv("SQLSERVER")
end

function M.database()
  return os.getenv("SQLDB") or "DW"
end

function M.auth()
  return os.getenv("SQLAUTH") or "-G"
end

-- Stable string identifying the current connection (used as a cache key)
function M.cache_key()
  local backend, duckdb_path = M.backend()
  if backend == "duckdb" then
    return "duckdb:" .. duckdb_path
  end
  return (M.server() or "localhost") .. ":" .. M.database() .. ":" .. M.auth()
end

-- Resolve the SQL server, prompting for a 1Password item when SQLSERVER is unset
function M.ensure_sqlserver()
  local server = M.server()
  if server and server ~= "" then
    return server
  end

  local item = vim.fn.input("SQLSERVER not set. 1Password item (empty to cancel): ")
  vim.api.nvim_echo({ { "" } }, false, {})
  if item == "" then
    return nil
  end

  local result = vim.fn.system({ "op", "read", "op://Crayon/" .. item .. "/credential" })
  if vim.v.shell_error ~= 0 or vim.trim(result) == "" then
    vim.api.nvim_echo({ { "Failed to read '" .. item .. "' from 1Password", "ErrorMsg" } }, false, {})
    return nil
  end

  -- Persist for the rest of this nvim session so we only prompt once
  vim.env.SQLSERVER = vim.trim(result)
  vim.env.SQLITEM = item
  return vim.env.SQLSERVER
end

local function reset_schema_cache(warm)
  local ok, schema = pcall(require, "sql.schema")
  if ok then
    schema.clear_cache()
    if warm and schema.is_configured() then
      schema.get_tables(function() end) -- warm the completion cache
    end
  end
end

-- :SqlDb — switch database, keeping the server
function M.switch_database(name)
  vim.env.SQLDB = name
  reset_schema_cache(false)
  print("SQL database: " .. name .. " (schema cache cleared)")
end

-- :SqlConn — switch to a local DuckDB file or a 1Password item (same lookup
-- as the `sql` shell function)
function M.switch_connection(target)
  local as_file = vim.fn.expand(target)
  if vim.fn.filereadable(as_file) == 1 then
    vim.env.DUCKDB = vim.fn.fnamemodify(as_file, ":p")
    vim.env.SQLSERVER = nil
    vim.env.SQLITEM = nil
    reset_schema_cache(true)
    print("SQL connection: " .. vim.fn.fnamemodify(as_file, ":t"))
    return
  end

  print("Fetching credential for '" .. target .. "' from 1Password...")
  local stdout_lines, stderr_lines = {}, {}
  vim.fn.jobstart({ "op", "read", "op://Crayon/" .. target .. "/credential" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then vim.list_extend(stdout_lines, data) end
    end,
    on_stderr = function(_, data)
      if data then vim.list_extend(stderr_lines, data) end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local cred = vim.trim(table.concat(stdout_lines, ""))
        if code ~= 0 or cred == "" then
          vim.api.nvim_echo({
            { "1Password lookup failed for '" .. target .. "': ", "ErrorMsg" },
            { vim.trim(table.concat(stderr_lines, " ")), "ErrorMsg" },
          }, true, {})
          return
        end
        vim.env.SQLSERVER = cred
        vim.env.SQLITEM = target
        vim.env.DUCKDB = nil
        reset_schema_cache(true)
        print("SQL connection: " .. target .. "/" .. M.database())
      end)
    end,
  })
end

-- Tab completion for :SqlConn — 1Password item titles, fetched once per session
function M.op_item_titles()
  if not vim.g.sql_op_items then
    local out = vim.fn.systemlist({ "op", "item", "list", "--vault", "Crayon", "--format=json" })
    if vim.v.shell_error == 0 then
      local ok, items = pcall(vim.json.decode, table.concat(out, ""))
      if ok and type(items) == "table" then
        local titles = {}
        for _, it in ipairs(items) do
          table.insert(titles, it.title)
        end
        vim.g.sql_op_items = titles
      end
    end
    vim.g.sql_op_items = vim.g.sql_op_items or {}
  end
  return vim.g.sql_op_items
end

-- Statusline segment: server/db (or the DuckDB file), red when the name
-- looks like production
function M.statusline()
  local backend, duckdb_path = M.backend()
  local text
  if backend == "duckdb" then
    text = "󰆼 " .. vim.fn.fnamemodify(duckdb_path, ":t")
  else
    local label = os.getenv("SQLITEM")
    if not label then
      local server = M.server()
      label = server and server:match("^[^,;%s]+") or nil
    end
    if not label then
      return "%#SqlConnNone#󰆼 no connection%*"
    end
    text = "󰆼 " .. label .. "/" .. M.database()
  end
  local hl = text:lower():match("pro?d") and "SqlConnProd" or "SqlConn"
  return "%#" .. hl .. "#" .. text .. "%*"
end

M.STATUSLINE = "%f %h%w%m%r%=%{%v:lua.ClaudeStatus.component()%}%{%v:lua.require'sql.connection'.statusline()%}  %-14.(%l,%c%V%) %P"

function M.setup_statusline_hl()
  local st = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  vim.api.nvim_set_hl(0, "SqlConn", { fg = "#fabd2f", bg = st.bg, bold = true })
  vim.api.nvim_set_hl(0, "SqlConnProd", { fg = "#fb4934", bg = st.bg, bold = true })
  vim.api.nvim_set_hl(0, "SqlConnNone", { fg = "#928374", bg = st.bg })
end

return M
