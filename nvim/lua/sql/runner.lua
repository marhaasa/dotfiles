-- Query/script execution: builds the backend command, runs it with progress
-- feedback and Ctrl+C cancellation, and routes results to VisiData (queries)
-- or a floating window (scripts, errors).
local connection = require("sql.connection")
local ui = require("sql.ui")

local M = {}

-- The last query result is persisted so it can be reopened without re-running
M.LAST_RESULT = vim.fn.stdpath("state") .. "/sql-last-result.csv"

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

-- Open a result CSV in VisiData (terminal buffer replaces current window)
function M.open_result_in_visidata(path)
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  vim.fn.termopen({ "vd", "-f", "csv", path }, {
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
  if vim.fn.filereadable(M.LAST_RESULT) == 0 then
    vim.api.nvim_echo({ { "No previous SQL result", "WarningMsg" } }, false, {})
    return
  end
  M.open_result_in_visidata(M.LAST_RESULT)
end

function M.run_query()
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
    if code ~= 0 then
      vim.api.nvim_echo({ { "Query cancelled or failed after ", "Normal" }, { time_str, "Number" } }, false, {})
    else
      vim.api.nvim_echo({ { "Query completed in ", "Normal" }, { time_str, "Number" } }, false, {})
    end

    local failed, clean_lines
    if is_duckdb then
      -- duckdb -csv already emits clean CSV; only trim trailing blank lines
      clean_lines = vim.list_slice(result_lines)
      while #clean_lines > 0 and clean_lines[#clean_lines] == "" do
        table.remove(clean_lines)
      end
      failed = code ~= 0 or #clean_lines == 0
    else
      local res = require("sql.result").process(result_lines)
      failed = code ~= 0 or not res.ok
      clean_lines = failed and res.lines or res.csv_lines
    end

    if failed then
      ui.open_float(clean_lines, { filetype = "sql" })
    else
      -- Persist the result (reopen with <leader>sv) and open VisiData.
      -- Both backends produce CSV; the sqlcmd path is re-encoded with
      -- proper quoting by sql/result.lua.
      local f = io.open(M.LAST_RESULT, "w")
      for _, line in ipairs(clean_lines) do
        f:write(line .. "\n")
      end
      f:close()

      M.open_result_in_visidata(M.LAST_RESULT)
    end
  end)
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
