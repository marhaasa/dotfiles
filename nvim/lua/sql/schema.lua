-- Backend/credential state (env vars, cache key) lives in sql/connection.lua
local connection = require("sql.connection")

local M = {}

local cache = {
  tables = {},
  columns = {},
  views = {},
  last_updated = {},
  connection_params = nil,
}

local CACHE_TTL = 300 -- 5 minutes

local function get_backend()
  return connection.backend()
end

-- Field separator in query output: sqlcmd is invoked with -s ",",
-- duckdb -list mode emits pipe-separated rows
local function get_field_separator()
  return get_backend() == "duckdb" and "|" or ","
end

local function is_cache_valid(key)
  local current_connection = connection.cache_key()
  if cache.connection_params ~= current_connection then
    cache = { tables = {}, columns = {}, views = {}, last_updated = {}, connection_params = current_connection }
    return false
  end

  local last_update = cache.last_updated[key] or 0
  return (os.time() - last_update) < CACHE_TTL
end

local function execute_query(query, callback)
  local backend, duckdb_path = get_backend()
  local cmd

  if backend == "duckdb" then
    if vim.fn.executable("duckdb") == 0 then
      callback(nil, "duckdb not found in PATH")
      return
    end
    -- -readonly allows concurrent introspection queries (DuckDB permits
    -- multiple read-only connections but only one read-write)
    cmd = { "duckdb", "-readonly", "-list", "-noheader", duckdb_path, "-c", query }
  else
    if vim.fn.executable("sqlcmd") == 0 then
      callback(nil, "sqlcmd not found in PATH")
      return
    end

    cmd = { "sqlcmd", "-S", connection.server(), "-d", connection.database(), connection.auth(),
      "-l", "5", "-Q", query, "-h", "-1", "-s", ",", "-W" }
  end

  -- Debug info available via <leader>ss if needed

  local result = {}
  local stderr_output = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" and not line:match("^%-+") and not line:match("^%(%d+ rows affected%)$") then
            table.insert(result, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_output, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        callback(result, nil)
      else
        local error_msg = "Query failed with exit code: " .. code
        if #stderr_output > 0 then
          error_msg = error_msg .. "\nSTDERR: " .. table.concat(stderr_output, "\n")
        end
        -- Error details available via debug if needed
        callback(nil, error_msg)
      end
    end,
  })
end

function M.get_tables(callback)
  local cache_key = "tables"

  if is_cache_valid(cache_key) and #cache.tables > 0 then
    callback(cache.tables, nil)
    return
  end

  local query
  if get_backend() == "duckdb" then
    query = [[
      SELECT table_schema || '.' || table_name
      FROM information_schema.tables
      WHERE table_type = 'BASE TABLE'
      ORDER BY table_schema, table_name
    ]]
  else
    query = [[
      SELECT TABLE_SCHEMA + '.' + TABLE_NAME as FULL_TABLE_NAME
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')
      ORDER BY TABLE_SCHEMA, TABLE_NAME
    ]]
  end

  execute_query(query, function(result, error)
    if error then
      callback({}, error)
      return
    end

    local tables = {}
    for _, line in ipairs(result) do
      local table_name = line:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
      if table_name ~= "" then
        table.insert(tables, table_name)
      end
    end

    cache.tables = tables
    cache.last_updated[cache_key] = os.time()
    callback(tables, nil)
  end)
end

function M.get_columns(table_or_view_name, callback)
  local cache_key = "columns:" .. table_or_view_name

  if is_cache_valid(cache_key) and cache.columns[table_or_view_name] then
    callback(cache.columns[table_or_view_name], nil)
    return
  end

  -- Handle both "table/view" and "schema.table/view" formats
  local schema, tbl_or_view = table_or_view_name:match("^([^%.]+)%.([^%.]+)$")
  local query

  if schema and tbl_or_view then
    -- Schema-qualified table/view name
    query = string.format(
      [[
      SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = '%s' AND TABLE_NAME = '%s'
      ORDER BY ORDINAL_POSITION
    ]],
      schema:gsub("'", "''"),
      tbl_or_view:gsub("'", "''")
    )
  else
    -- Just table/view name (search all schemas)
    query = string.format(
      [[
      SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = '%s'
      ORDER BY ORDINAL_POSITION
    ]],
      table_or_view_name:gsub("'", "''")
    )
  end

  -- INFORMATION_SCHEMA.COLUMNS is identical on SQL Server and DuckDB
  execute_query(query, function(result, error)
    if error then
      callback({}, error)
      return
    end

    local sep = get_field_separator()
    local columns = {}
    for _, line in ipairs(result) do
      local parts = {}
      for part in line:gmatch("[^" .. sep .. "]+") do
        local trimmed_part = part:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
        table.insert(parts, trimmed_part)
      end

      if #parts >= 2 then
        local column_name = parts[1]
        local data_type = parts[2]
        local is_nullable = parts[3] or "YES"
        local default_value = parts[4] or ""

        table.insert(columns, {
          name = column_name,
          type = data_type,
          nullable = is_nullable == "YES",
          default = default_value ~= "NULL" and default_value or nil,
        })
      end
    end

    cache.columns[table_or_view_name] = columns
    cache.last_updated[cache_key] = os.time()
    callback(columns, nil)
  end)
end

function M.get_views(callback)
  local cache_key = "views"

  if is_cache_valid(cache_key) and #cache.views > 0 then
    callback(cache.views, nil)
    return
  end

  local query
  if get_backend() == "duckdb" then
    query = [[
      SELECT table_schema || '.' || table_name
      FROM information_schema.tables
      WHERE table_type = 'VIEW'
      ORDER BY table_schema, table_name
    ]]
  else
    query = [[
      SELECT TABLE_SCHEMA + '.' + TABLE_NAME as FULL_VIEW_NAME
      FROM INFORMATION_SCHEMA.VIEWS
      WHERE TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')
      ORDER BY TABLE_SCHEMA, TABLE_NAME
    ]]
  end

  execute_query(query, function(result, error)
    if error then
      callback({}, error)
      return
    end

    local views = {}
    for _, line in ipairs(result) do
      local view_name = line:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
      if view_name ~= "" then
        table.insert(views, view_name)
      end
    end

    cache.views = views
    cache.last_updated[cache_key] = os.time()
    callback(views, nil)
  end)
end

function M.is_configured()
  if get_backend() == "duckdb" then
    return vim.fn.executable("duckdb") == 1
  end
  return connection.server() ~= nil and vim.fn.executable("sqlcmd") == 1
end

function M.clear_cache()
  cache = {
    tables = {},
    columns = {},
    views = {},
    last_updated = {},
    connection_params = connection.cache_key(),
  }
end

function M.get_cache_status()
  local current_time = os.time()
  local status = {}

  status.connection = cache.connection_params or "not connected"
  status.tables_count = #cache.tables
  status.views_count = #cache.views
  status.columns_count = 0
  for _ in pairs(cache.columns) do
    status.columns_count = status.columns_count + 1
  end

  status.last_table_update = cache.last_updated.tables
  if status.last_table_update then
    status.tables_age = current_time - status.last_table_update
  end

  return status
end

return M

