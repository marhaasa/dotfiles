-- SQL Schema completion source for blink.cmp
local M = {}

local sql_schema

function M.new()
  return setmetatable({}, { __index = M })
end

-- Words that can never be a table name or alias
local KEYWORDS = {}
for _, kw in ipairs({
  "where", "join", "inner", "left", "right", "full", "cross", "outer", "on",
  "group", "order", "having", "union", "except", "intersect", "select", "set",
  "as", "with", "and", "or", "not", "when", "then", "case", "end", "limit",
  "offset", "option", "pivot", "unpivot", "apply", "values", "go", "from",
  "into", "update", "top", "distinct", "asc", "desc", "by",
}) do
  KEYWORDS[kw] = true
end

-- Cursor is where a column name belongs (WHERE clause, join condition,
-- select list, ...). `text` is everything before the cursor, lowercased.
local COLUMN_TAILS = {
  "%f[%w]where%s+[%w_%[%]]*$",
  "%f[%w]and%s+[%w_%[%]]*$",
  "%f[%w]or%s+[%w_%[%]]*$",
  "%f[%w]on%s+[%w_%[%]]*$",
  "%f[%w]having%s+[%w_%[%]]*$",
  "%f[%w]group%s+by%s+[%w_%[%]]*$",
  "%f[%w]order%s+by%s+[%w_%[%]]*$",
  "%f[%w]select%s+[%w_%[%]]*$",
  "%f[%w]select%s+distinct%s+[%w_%[%]]*$",
  "%f[%w]set%s+[%w_%[%]]*$",
}

-- Cursor is where a table name belongs
local TABLE_TAILS = {
  "%f[%w]from%s+[%w_%.%[%]]*$",
  "%f[%w]join%s+[%w_%.%[%]]*$",
  "%f[%w]into%s+[%w_%.%[%]]*$",
  "%f[%w]update%s+[%w_%.%[%]]*$",
}

local function matches_any(text, patterns)
  for _, pat in ipairs(patterns) do
    if text:match(pat) then
      return true
    end
  end
  return false
end

-- Scan the whole buffer for table references (FROM/JOIN/UPDATE/INTO) and
-- their aliases. Returns a list of table names and an alias -> table map.
function M:get_buffer_tables()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = " " .. table.concat(lines, "\n") .. " "
  local ltext = text:lower()

  local tables, seen, aliases = {}, {}, {}
  for _, kw in ipairs({ "from", "join", "into", "update" }) do
    for pos in ltext:gmatch("%f[%w]" .. kw .. "%f[%W]()") do
      local ws, token = text:match("^(%s*)([%[%]%w_%.#]+)", pos)
      if token then
        local name = token:gsub("[%[%]]", "")
        if name ~= "" and not KEYWORDS[name:lower()] then
          if not seen[name:lower()] then
            seen[name:lower()] = true
            table.insert(tables, name)
          end
          -- optional alias: "AS x" or bare "x" (but never a keyword)
          local after = pos + #ws + #token
          local alias = text:match("^%s+[aA][sS]%s+([%w_]+)", after)
            or text:match("^%s+([%w_]+)", after)
          if alias and not KEYWORDS[alias:lower()] then
            aliases[alias:lower()] = name
          end
        end
      end
    end
  end
  return tables, aliases
end

local function make_column_items(columns, source_table)
  local items = {}
  for _, column in ipairs(columns or {}) do
    table.insert(items, {
      label = column.name,
      kind = 5, -- Field
      detail = column.type .. (not column.nullable and " NOT NULL" or ""),
      labelDetails = source_table and { description = source_table } or nil,
      insertText = column.name,
    })
  end
  return items
end

-- Columns of a single table
local function complete_columns(table_name, callback)
  sql_schema.get_columns(table_name, function(columns, error)
    if error or not columns then
      callback({ items = {} })
      return
    end
    callback({ items = make_column_items(columns) })
  end)
end

-- Columns of every table referenced in the statement, labeled by table
local function complete_columns_for_tables(table_names, callback)
  if #table_names == 0 then
    callback({ items = {} })
    return
  end
  local items = {}
  local remaining = #table_names
  for _, tbl in ipairs(table_names) do
    sql_schema.get_columns(tbl, function(columns, _)
      vim.list_extend(items, make_column_items(columns, #table_names > 1 and tbl or nil))
      remaining = remaining - 1
      if remaining == 0 then
        callback({ items = items })
      end
    end)
  end
end

-- All tables and views, optionally restricted to one schema
local function complete_tables_and_views(schema_only, callback)
  local items = {}
  local remaining = 2

  local function add(names, kind, what)
    for _, full_name in ipairs(names or {}) do
      if schema_only then
        local prefix = schema_only:lower() .. "."
        if full_name:lower():sub(1, #prefix) == prefix then
          local short = full_name:sub(#schema_only + 2)
          table.insert(items, {
            label = short,
            kind = kind,
            detail = what .. " in " .. schema_only,
            insertText = short,
          })
        end
      else
        table.insert(items, {
          label = full_name,
          kind = kind,
          detail = what,
          insertText = full_name,
        })
      end
    end
    remaining = remaining - 1
    if remaining == 0 then
      callback({ items = items })
    end
  end

  sql_schema.get_tables(function(tables, error)
    add(not error and tables or {}, 21, "table") -- Class
  end)
  sql_schema.get_views(function(views, error)
    add(not error and views or {}, 8, "view") -- Interface
  end)
end

function M:get_completions(context, callback)
  if vim.bo.filetype ~= "sql" then
    callback({ items = {} })
    return
  end

  if not sql_schema then
    local ok, module = pcall(require, 'sql.schema')
    if not ok then
      callback({ items = {} })
      return
    end
    sql_schema = module
  end

  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = line:sub(1, col)

  -- Everything from buffer start to the cursor, for clause detection that
  -- works across line breaks
  local prev_lines = vim.api.nvim_buf_get_lines(0, 0, row - 1, false)
  table.insert(prev_lines, before_cursor)
  local full_before = table.concat(prev_lines, "\n"):lower()

  local buffer_tables, aliases = M:get_buffer_tables()

  -- Dot completions (most specific first)
  local schema_table_column = before_cursor:match("([%w_]+%.[%w_]+)%.[%w_]*$")
  local dot_word = before_cursor:match("([%w_]+)%.[%w_]*$")
  local schema_only = before_cursor:match("([%w_]+)%.$")

  if schema_table_column then
    -- schema.table.<column>
    complete_columns(schema_table_column, callback)
  elseif dot_word and aliases[dot_word:lower()] then
    -- alias.<column>  (alias resolved from FROM/JOIN in the buffer)
    complete_columns(aliases[dot_word:lower()], callback)
  elseif schema_only then
    -- schema.<table or view>
    complete_tables_and_views(schema_only, callback)
  elseif dot_word then
    -- table.<column> (unqualified table name, searched across schemas)
    complete_columns(dot_word, callback)
  elseif matches_any(full_before, TABLE_TAILS) then
    -- after FROM/JOIN/INTO/UPDATE: table names
    complete_tables_and_views(nil, callback)
  elseif matches_any(full_before, COLUMN_TAILS) then
    -- after WHERE/AND/OR/ON/HAVING/GROUP BY/ORDER BY/SELECT/SET: columns
    -- from every table referenced in the buffer
    complete_columns_for_tables(buffer_tables, callback)
  elseif context and context.trigger and context.trigger.character == " " then
    -- Space is an unblocked trigger character in sql buffers (see blink.lua)
    -- so recognized clauses above pop automatically; a bare space in any
    -- other context should not dump the full table list.
    callback({ items = {} })
  else
    complete_tables_and_views(nil, callback)
  end
end

function M:get_trigger_characters()
  return { ".", " ", "," }
end

function M:should_show_completions(context)
  return vim.bo.filetype == "sql"
end

return M
