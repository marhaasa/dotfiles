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
    -- Schema-to-table/view completion: show tables and views in this schema
    local items = {}
    local completed_count = 0
    local expected_count = 2
    
    local function check_completion()
      completed_count = completed_count + 1
      if completed_count >= expected_count then
        callback({ items = items })
      end
    end
    
    -- Get tables
    sql_schema.get_tables(function(tables, error)
      if not error and tables then
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
      end
      check_completion()
    end)
    
    -- Get views
    sql_schema.get_views(function(views, error)
      if not error and views then
        local schema_prefix = schema_only:lower() .. "."
        
        for _, view_name in ipairs(views) do
          if view_name:lower():sub(1, #schema_prefix) == schema_prefix then
            -- Extract just the view name without schema
            local just_view_name = view_name:sub(#schema_only + 2) -- +2 for the dot
            
            table.insert(items, {
              label = just_view_name,
              kind = 8, -- Interface (different from tables)
              detail = "view in " .. schema_only,
              insertText = just_view_name,
            })
          end
        end
      end
      check_completion()
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
    -- Table and view completion - show all schema.table and schema.view combinations
    local items = {}
    local completed_count = 0
    local expected_count = 2
    
    local function check_completion()
      completed_count = completed_count + 1
      if completed_count >= expected_count then
        callback({ items = items })
      end
    end
    
    -- Get tables
    sql_schema.get_tables(function(tables, error)
      if not error and tables then
        for _, table_name in ipairs(tables) do
          table.insert(items, {
            label = table_name,
            kind = 21, -- Class
            detail = "table",
            insertText = table_name,
          })
        end
      end
      check_completion()
    end)
    
    -- Get views
    sql_schema.get_views(function(views, error)
      if not error and views then
        for _, view_name in ipairs(views) do
          table.insert(items, {
            label = view_name,
            kind = 8, -- Interface
            detail = "view",
            insertText = view_name,
          })
        end
      end
      check_completion()
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