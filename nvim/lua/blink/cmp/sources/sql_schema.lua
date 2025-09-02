-- SQL Schema completion source for blink.cmp
local M = {}

local sql_schema

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_select_context(line, col)
  -- Look for SELECT ... FROM pattern to extract table names
  local line_lower = line:lower()
  
  -- Check if we're between SELECT and FROM
  local select_pos = line_lower:find("select")
  local from_pos = line_lower:find("from")
  
  if not select_pos or not from_pos or col <= select_pos or col >= from_pos then
    return nil
  end
  
  -- Extract the FROM clause to get table names
  local from_part = line:sub(from_pos + 4):match("^%s*([^%s,;]+)")
  if from_part then
    -- Handle schema.table format
    local schema_table = from_part:match("([%w_]+%.[%w_]+)")
    if schema_table then
      return { table_name = schema_table }
    end
    
    -- Handle just table name
    local table_name = from_part:match("([%w_]+)")
    if table_name then
      return { table_name = table_name }
    end
  end
  
  return nil
end

function M:get_completions(context, callback)
  -- Only activate for SQL files
  if vim.bo.filetype ~= "sql" then
    callback({ items = {} })
    return
  end

  -- Lazy load sql_schema
  if not sql_schema then
    local ok, module = pcall(require, 'utils.sql_schema')
    if not ok then
      callback({ items = {} })
      return
    end
    sql_schema = module
  end

  -- Check what kind of completion this is
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = line:sub(1, col)
  
  -- Check for column completion: schema.table.column or table.column
  local schema_table_column = before_cursor:match("([%w_]+%.[%w_]+)%.%w*$") -- schema.table.column
  local table_column = before_cursor:match("([%w_]+)%.%w*$") -- table.column (but not schema.table)
  
  -- Check for schema-to-table completion: schema.
  local schema_only = before_cursor:match("([%w_]+)%.$")
  
  -- Check for SELECT column completion: between SELECT and FROM
  local select_context = M:get_select_context(line, col)
  
  if select_context then
    -- Column completion for SELECT clause
    sql_schema.get_columns(select_context.table_name, function(columns, error)
      if error or not columns then
        callback({ items = {} })
        return
      end
      
      local items = {}
      for _, column in ipairs(columns) do
        table.insert(items, {
          label = column.name,
          kind = 5, -- Field
          detail = column.type .. (not column.nullable and " NOT NULL" or ""),
          insertText = column.name,
        })
      end
      
      callback({ items = items })
    end)
  elseif schema_table_column then
    -- Column completion for schema.table.column
    sql_schema.get_columns(schema_table_column, function(columns, error)
      if error or not columns then
        callback({ items = {} })
        return
      end
      
      local items = {}
      for _, column in ipairs(columns) do
        table.insert(items, {
          label = column.name,
          kind = 5, -- Field
          detail = column.type .. (not column.nullable and " NOT NULL" or ""),
          insertText = column.name,
        })
      end
      
      callback({ items = items })
    end)
  elseif schema_only then
    -- Schema-to-table completion: show tables in this schema
    sql_schema.get_tables(function(tables, error)
      if error or not tables then
        callback({ items = {} })
        return
      end
      
      local items = {}
      local schema_prefix = schema_only:lower() .. "."
      
      for _, table_name in ipairs(tables) do
        if table_name:lower():sub(1, #schema_prefix) == schema_prefix then
          -- Extract just the table name without schema
          local just_table_name = table_name:sub(#schema_only + 2) -- +2 for the dot
          
          table.insert(items, {
            label = just_table_name,
            kind = 21, -- Class
            detail = "table in " .. schema_only,
            insertText = just_table_name,
          })
        end
      end
      
      callback({ items = items })
    end)
  elseif table_column and not table_column:match("%.") then
    -- Column completion for just table.column (no schema)
    sql_schema.get_columns(table_column, function(columns, error)
      if error or not columns then
        callback({ items = {} })
        return
      end
      
      local items = {}
      for _, column in ipairs(columns) do
        table.insert(items, {
          label = column.name,
          kind = 5, -- Field
          detail = column.type .. (not column.nullable and " NOT NULL" or ""),
          insertText = column.name,
        })
      end
      
      callback({ items = items })
    end)
  else
    -- Table completion - show all schema.table combinations
    sql_schema.get_tables(function(tables, error)
      if error or not tables then
        callback({ items = {} })
        return
      end
      
      local items = {}
      for _, table_name in ipairs(tables) do
        table.insert(items, {
          label = table_name,
          kind = 21, -- Class
          detail = "table",
          insertText = table_name,
        })
      end
      
      callback({ items = items })
    end)
  end
end

function M:get_trigger_characters()
  return { ".", " ", "," }
end

function M:should_show_completions(context)
  return vim.bo.filetype == "sql"
end

return M