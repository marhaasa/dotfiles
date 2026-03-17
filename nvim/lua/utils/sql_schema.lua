local M = {}

local cache = {
  tables = {},
  columns = {},
  views = {},
  last_updated = {},
  connection_params = nil,
}

local CACHE_TTL = 300 -- 5 minutes

local function get_connection_params()
  local server = os.getenv("SQLSERVER") or "localhost"
  local db = os.getenv("SQLDB") or "DW"
  local auth = os.getenv("SQLAUTH") or "-G"
  return server .. ":" .. db .. ":" .. auth
end

local function is_cache_valid(key)
  local current_connection = get_connection_params()
  if cache.connection_params ~= current_connection then
    cache = { tables = {}, columns = {}, views = {}, last_updated = {}, connection_params = current_connection }
    return false
  end

  local last_update = cache.last_updated[key] or 0
  return (os.time() - last_update) < CACHE_TTL
end

local function execute_sqlcmd(query, callback)
  if vim.fn.executable("sqlcmd") == 0 then
    callback(nil, "sqlcmd not found in PATH")
    return
  end

  local server = os.getenv("SQLSERVER")
  local db = os.getenv("SQLDB") or "DW"
  local auth = os.getenv("SQLAUTH") or "-G"

  local cmd = { "sqlcmd", "-S", server, "-d", db, auth, "-l", "5", "-Q", query, "-h", "-1", "-s", ",", "-W" }

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

  local query = [[
    SELECT TABLE_SCHEMA + '.' + TABLE_NAME as FULL_TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_TYPE = 'BASE TABLE' 
    AND TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')
    ORDER BY TABLE_SCHEMA, TABLE_NAME
  ]]

  execute_sqlcmd(query, function(result, error)
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

  execute_sqlcmd(query, function(result, error)
    if error then
      callback({}, error)
      return
    end

    local columns = {}
    for _, line in ipairs(result) do
      local parts = {}
      for part in line:gmatch("[^,]+") do
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

  local query = [[
    SELECT TABLE_SCHEMA + '.' + TABLE_NAME as FULL_VIEW_NAME
    FROM INFORMATION_SCHEMA.VIEWS 
    WHERE TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')
    ORDER BY TABLE_SCHEMA, TABLE_NAME
  ]]

  execute_sqlcmd(query, function(result, error)
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
  return os.getenv("SQLSERVER") ~= nil and vim.fn.executable("sqlcmd") == 1
end

function M.clear_cache()
  cache = {
    tables = {},
    columns = {},
    views = {},
    last_updated = {},
    connection_params = get_connection_params(),
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

