-- Query/script execution: builds the backend command, runs it with progress
-- feedback and Ctrl+C cancellation, and routes results to VisiData (queries),
-- CSVs under SAVE_DIR (saved queries), or a floating window (scripts, errors).
-- A query with several SELECTs yields one CSV (and one VisiData sheet) per
-- result set.
local connection = require("sql.connection")
local ui = require("sql.ui")

local M = {}

-- The last query result is persisted here as one NN[-label].csv per result
-- set, so it can be reopened or saved without re-running
M.LAST_RESULT = vim.fn.stdpath("state") .. "/sql-last-result"

-- Where <leader>se / <leader>sE keep results: name.csv for a single grid,
-- name/NN-label.csv for several
M.SAVE_DIR = vim.fn.expand("~/Repos/saved queries")

local function format_elapsed(start_time, precise)
  local elapsed = (vim.loop.now() - start_time) / 1000
  local mins = math.floor(elapsed / 60)
  local secs = math.floor(elapsed % 60)
  if mins > 0 then
    return string.format("%dm %02ds", mins, secs)
  end
  return precise and string.format("%.1fs", elapsed) or string.format("%ds", secs)
end

-- Run cmd (argv list) with progress in the echo area; on_done(code,
-- result_lines, time_str) runs on the main loop when the job exits.
-- on_cancel (optional) runs when the user aborts with Ctrl+C.
local function run_job(label, cmd, on_done, on_cancel)
  local start_time = vim.loop.now()
  local progress_timer = vim.loop.new_timer()
  local job_id

  vim.api.nvim_echo({ { "Running SQL " .. label .. "...", "Normal" } }, false, {})

  progress_timer:start(1000, 1000, function()
    local time_str = format_elapsed(start_time, false)
    vim.schedule(function()
      vim.api.nvim_echo({
        { "SQL " .. label .. " running... ", "Normal" },
        { time_str,                          "Number" },
        { " (Press Ctrl+C to cancel)",       "Comment" },
      }, false, {})
    end)
  end)

  local function stop_progress()
    if progress_timer and not progress_timer:is_closing() then
      progress_timer:stop()
      progress_timer:close()
    end
  end

  local result_lines = {}
  local function collect(_, data)
    if data then
      vim.list_extend(result_lines, data)
    end
  end

  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = collect,
    on_stderr = collect,
    on_exit = function(_, code)
      stop_progress()
      local time_str = format_elapsed(start_time, true)
      vim.schedule(function()
        on_done(code, result_lines, time_str)
      end)
    end,
  })

  vim.keymap.set('n', '<C-c>', function()
    if job_id then
      vim.fn.jobstop(job_id)
      stop_progress()
      if on_cancel then
        on_cancel()
      end
      vim.api.nvim_echo({ { "SQL " .. label .. " cancelled", "WarningMsg" } }, false, {})
    end
  end, { buffer = 0, desc = "Cancel SQL " .. label })
end

-- CSV files of the last result, in result-set order
local function last_result_files()
  return vim.fn.glob(M.LAST_RESULT .. "/*.csv", false, true)
end

-- Open result CSVs in VisiData, one sheet each (the first file is the active
-- sheet, `S` lists them all); the terminal buffer replaces the current window
function M.open_result_in_visidata(paths)
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  local cmd = { "vd", "-f", "csv" }
  vim.list_extend(cmd, paths)
  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(term_buf) then
          vim.api.nvim_buf_delete(term_buf, { force = true })
        end
      end)
    end
  })
  vim.cmd("startinsert")
end

function M.open_last_result()
  local files = last_result_files()
  if #files == 0 then
    vim.api.nvim_echo({ { "No previous SQL result", "WarningMsg" } }, false, {})
    return
  end
  M.open_result_in_visidata(files)
end

-- Result-set label → filename-safe fragment (nil when nothing is left)
local function safe_label(label)
  local s = label:gsub("[/\\%c]", "-")
  s = vim.trim(s):sub(1, 60)
  return s ~= "" and s or nil
end

-- Write result sets to LAST_RESULT as NN[-label].csv; returns the paths.
-- The label doubles as the VisiData sheet name.
local function persist_sets(sets)
  vim.fn.delete(M.LAST_RESULT, "rf")
  vim.fn.mkdir(M.LAST_RESULT, "p")
  local files = {}
  for i, set in ipairs(sets) do
    local label = set.label and safe_label(set.label)
    local path = string.format("%s/%02d%s.csv", M.LAST_RESULT, i, label and ("-" .. label) or "")
    local f = io.open(path, "w")
    for _, line in ipairs(set.csv_lines) do
      f:write(line .. "\n")
    end
    f:close()
    files[#files + 1] = path
  end
  return files
end

-- Default name for a saved result: <buffer name>-<timestamp>
local function default_save_name()
  local base = vim.fn.expand("%:t:r")
  if base == "" then
    base = "query"
  end
  return base .. "-" .. os.date("%Y%m%d-%H%M%S")
end

local function not_saved()
  vim.api.nvim_echo({ { "Result not saved (still available with <leader>sv)", "WarningMsg" } }, false, {})
end

-- A bare name lands in SAVE_DIR; an absolute or ~ path is used as given
local function resolve_dest(name)
  if name:match("^[/~]") then
    return vim.fn.expand(name)
  end
  return M.SAVE_DIR .. "/" .. name
end

-- Copy result CSVs into SAVE_DIR under a name the user confirms: a single
-- result set becomes name.csv, several become a folder name/ holding one
-- NN-label.csv per set. rows (optional) is the total data row count.
function M.save_result(files, rows)
  local multi = #files > 1
  vim.ui.input({
    prompt = multi and ("Save " .. #files .. " result sets to folder: ") or "Save result as: ",
    default = default_save_name() .. (multi and "" or ".csv"),
  }, function(name)
    if not name or vim.trim(name) == "" then
      not_saved()
      return
    end
    name = vim.trim(name)

    local dest, exists
    if multi then
      dest = resolve_dest((name:gsub("%.csv$", "")))
      exists = vim.fn.isdirectory(dest) == 1
    else
      if not name:match("%.%w+$") then
        name = name .. ".csv"
      end
      dest = resolve_dest(name)
      exists = vim.fn.filereadable(dest) == 1
    end

    local shown = vim.fn.fnamemodify(dest, ":~") .. (multi and "/" or "")
    if exists and vim.fn.confirm(shown .. " exists. Overwrite?", "&Yes\n&No", 2) ~= 1 then
      not_saved()
      return
    end

    vim.fn.mkdir(multi and dest or vim.fn.fnamemodify(dest, ":h"), "p")
    for _, src in ipairs(files) do
      local target = multi and (dest .. "/" .. vim.fn.fnamemodify(src, ":t")) or dest
      local ok, err = vim.loop.fs_copyfile(src, target)
      if not ok then
        vim.api.nvim_echo({ { "Failed to save result: " .. tostring(err), "ErrorMsg" } }, false, {})
        return
      end
    end

    local what
    if multi then
      what = #files .. " result sets" .. (rows and string.format(" (%d rows)", rows) or "")
    else
      what = rows and (rows .. (rows == 1 and " row" or " rows")) or "result"
    end
    vim.api.nvim_echo({ { "Saved " .. what .. " → ", "Normal" }, { shown, "Directory" } }, false, {})
  end)
end

-- Save the most recent query result without re-running it
function M.save_last_result()
  local files = last_result_files()
  if #files == 0 then
    vim.api.nvim_echo({ { "No previous SQL result", "WarningMsg" } }, false, {})
    return
  end
  M.save_result(files)
end

-- Run the selection/buffer as a query. On success the result sets are written
-- to LAST_RESULT and on_success(files, rows) is called; errors open in a float.
local function execute_query(on_success)
  local lines = ui.selection_or_buffer()
  local backend, duckdb_path = connection.backend()
  local is_duckdb = backend == "duckdb"
  local cmd

  if is_duckdb then
    if vim.fn.executable("duckdb") == 0 then
      print("Error: duckdb not found in PATH")
      return
    end
    -- Keep newlines so `--` line comments don't swallow the rest of the query
    cmd = { "duckdb", "-csv", duckdb_path, "-c", table.concat(lines, '\n') }
  else
    if vim.fn.executable("sqlcmd") == 0 then
      print("Error: sqlcmd not found in PATH")
      return
    end
    local server = connection.ensure_sqlserver()
    if not server then
      vim.api.nvim_echo({ { "SQL query cancelled: no server", "WarningMsg" } }, false, {})
      return
    end

    -- jobstart passes argv directly (no shell), so the query needs no
    -- escaping; keep newlines so `--` line comments don't swallow the rest
    cmd = {
      "sqlcmd", "-S", server, "-d", connection.database(), connection.auth(),
      "-Q", table.concat(lines, '\n'),
      "-s", require("sql.result").SEP, -- separator that can't appear in data
      "-W",          -- trim trailing padding from values
      "-w", "65535", -- never wrap wide rows across lines
      -- go-sqlcmd truncates (max)-typed values at 256 chars by default; 8000
      -- is the flag's maximum. -y 0 (unlimited) would suppress the header row
      -- entirely (go-sqlcmd bug), so don't use it.
      "-y", "8000",
      "-k", "2",     -- replace control chars (embedded newlines) in values
      "-b",          -- exit non-zero on SQL errors
    }
  end

  run_job("query", cmd, function(code, result_lines, time_str)
    local failed, sets, error_lines
    if is_duckdb then
      -- duckdb -csv already emits clean CSV; only trim trailing blank lines
      local clean = vim.list_slice(result_lines)
      while #clean > 0 and clean[#clean] == "" do
        table.remove(clean)
      end
      failed = code ~= 0 or #clean == 0
      if failed then
        error_lines = clean
      else
        sets = { { csv_lines = clean, rows = #clean - 1 } }
      end
    else
      local res = require("sql.result").process(result_lines)
      failed = code ~= 0 or not res.ok
      if failed then
        error_lines = res.lines
      else
        sets = res.sets
      end
    end

    if code ~= 0 then
      vim.api.nvim_echo({ { "Query cancelled or failed after ", "Normal" }, { time_str, "Number" } }, false, {})
    else
      local msg = { { "Query completed in ", "Normal" }, { time_str, "Number" } }
      if sets and #sets > 1 then
        table.insert(msg, { string.format(" (%d result sets)", #sets), "Comment" })
      end
      vim.api.nvim_echo(msg, false, {})
    end

    if failed then
      ui.open_float(error_lines, { filetype = "sql" })
      return
    end

    -- Persist the result (reopen with <leader>sv, save with <leader>sE).
    -- Both backends produce CSV; the sqlcmd path is re-encoded with
    -- proper quoting by sql/result.lua.
    local rows = 0
    for _, set in ipairs(sets) do
      rows = rows + set.rows
    end
    on_success(persist_sets(sets), rows)
  end)
end

-- <leader>sq: query → VisiData
function M.run_query()
  execute_query(M.open_result_in_visidata)
end

-- <leader>se: query → CSV(s) in SAVE_DIR (prompts for the name)
function M.save_query()
  execute_query(M.save_result)
end

function M.run_script()
  local lines = ui.selection_or_buffer()

  -- Write to temp file: -i input keeps GO batches and :setvar working
  local tmp = vim.fn.tempname() .. ".sql"
  local f = io.open(tmp, "w")
  for _, line in ipairs(lines) do
    f:write(line .. "\n")
  end
  f:close()

  if vim.fn.executable("sqlcmd") == 0 then
    print("Error: sqlcmd not found in PATH")
    os.remove(tmp)
    return
  end
  local server = connection.ensure_sqlserver()
  if not server then
    os.remove(tmp)
    vim.api.nvim_echo({ { "SQL script cancelled: no server", "WarningMsg" } }, false, {})
    return
  end

  local cmd = { "sqlcmd", "-S", server, "-d", connection.database(), connection.auth(), "-i", tmp }

  run_job("script", cmd, function(code, result_lines, time_str)
    os.remove(tmp)

    local clean_lines = {}
    for _, line in ipairs(result_lines) do
      if line ~= "" then
        table.insert(clean_lines, line)
      end
    end

    local status_msg = code == 0
      and { "Script completed successfully in " .. time_str, "" }
      or { "Script failed (exit code " .. code .. ") after " .. time_str, "" }
    local display_lines = vim.list_extend(status_msg, clean_lines)

    local buf = ui.open_float(display_lines, {
      filetype = "sql",
      width = math.min(math.floor(vim.o.columns * 0.8), 120),
      height = math.min(math.floor(vim.o.lines * 0.6), #display_lines + 2),
      title = code == 0 and " Script Output " or " Script Error ",
    })
    vim.api.nvim_buf_add_highlight(buf, -1, code == 0 and "DiagnosticOk" or "DiagnosticError", 0, 0, -1)
  end, function()
    os.remove(tmp)
  end)
end

return M
