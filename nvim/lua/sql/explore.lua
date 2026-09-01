-- History, scratch buffers, and schema exploration for the SQL workflow
local ui = require("sql.ui")

local M = {}

-- Query history lives here (written by the `sql` shell function and :Sql)
M.SCRATCH_DIR = vim.fn.expand("~/.sql-scratch")

function M.new_scratch()
  vim.fn.mkdir(M.SCRATCH_DIR, "p")
  vim.cmd("edit " .. M.SCRATCH_DIR .. "/scratch-" .. os.date("%Y%m%d-%H%M%S") .. ".sql")
end

-- Fuzzy-find past queries, newest first
function M.history_picker()
  local files = vim.fn.glob(M.SCRATCH_DIR .. "/*.sql", false, true)
  -- legacy scratch files from the old /tmp location (pre-history sessions)
  vim.list_extend(files, vim.fn.glob("/tmp/scratch-*.sql", false, true))
  if #files == 0 then
    vim.api.nvim_echo({ { "No SQL history in " .. M.SCRATCH_DIR, "WarningMsg" } }, false, {})
    return
  end
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  local ok = pcall(function()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local make_entry = require("telescope.make_entry")
    pickers.new({}, {
      prompt_title = "SQL History",
      finder = finders.new_table({
        results = files,
        entry_maker = make_entry.gen_from_file({}),
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
    }):find()
  end)
  if not ok then
    -- Telescope unavailable: plain selector
    vim.ui.select(files, {
      prompt = "SQL history",
      format_item = function(f)
        return vim.fn.fnamemodify(f, ":t")
      end,
    }, function(choice)
      if choice then
        vim.cmd("edit " .. vim.fn.fnameescape(choice))
      end
    end)
  end
end

-- Describe the table under the cursor in a float (uses the schema cache;
-- resolves aliases via the completion source's buffer scan)
function M.describe_table()
  local word = vim.fn.expand("<cWORD>"):gsub("[%[%]]", ""):match("[%w_%.#]+")
  if not word or word == "" then
    vim.api.nvim_echo({ { "No table name under cursor", "WarningMsg" } }, false, {})
    return
  end

  local ok_src, src = pcall(require, "blink.cmp.sources.sql_schema")
  if ok_src then
    local _, aliases = src.get_buffer_tables(src)
    word = aliases[word:lower()] or word
  end

  local ok_schema, schema = pcall(require, "sql.schema")
  if not ok_schema or not schema.is_configured() then
    vim.api.nvim_echo({ { "No SQL connection configured", "WarningMsg" } }, false, {})
    return
  end

  schema.get_columns(word, function(columns, err)
    vim.schedule(function()
      if err or not columns or #columns == 0 then
        vim.api.nvim_echo({ { "No columns found for " .. word, "WarningMsg" } }, false, {})
        return
      end

      local name_w, type_w = 0, 0
      for _, c in ipairs(columns) do
        name_w = math.max(name_w, #c.name)
        type_w = math.max(type_w, #c.type)
      end

      local lines = {}
      for _, c in ipairs(columns) do
        table.insert(lines, string.format(
          "%-" .. name_w .. "s  %-" .. type_w .. "s  %s",
          c.name, c.type, c.nullable and "NULL" or "NOT NULL"))
      end

      ui.open_float(lines, {
        relative = "cursor",
        width = math.min(math.max(name_w + type_w + 12, #word + 4), vim.o.columns - 4),
        height = math.min(#lines, math.floor(vim.o.lines * 0.6)),
        title = " " .. word .. " ",
      })
    end)
  end)
end

return M
