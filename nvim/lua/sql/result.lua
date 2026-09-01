-- Turns go-sqlcmd tabular output into RFC 4180 CSV for VisiData.
--
-- sqlcmd must be invoked with `-s SEP` (unit separator) so the column
-- delimiter cannot collide with data: VisiData's psv/tsv loaders split on the
-- raw delimiter with no quote handling, so any `|`, quote, or bracket in a
-- value used to explode into extra columns. Re-encoding as quoted CSV lets
-- VisiData's csv loader (Python csv module) handle every character safely.
local M = {}

-- ASCII unit separator (0x1f). sqlcmd's -k 2 scrubs control characters from
-- char-typed column values before the separator is inserted, so SEP in the
-- output always means "column boundary".
M.SEP = "\31"

local function is_noise(line)
  return line == ""
    or line:match("^[%-\31]+$") ~= nil              -- header underline row
    or line:match("^%(%d+ rows? affected%)") ~= nil
    or line:match("^%(Rows affected: %d+%)") ~= nil
    or line:match("^Changed database context") ~= nil
    or line:match("^Warning:") ~= nil
end

local function count_sep(s)
  local _, n = s:gsub(M.SEP, "")
  return n
end

local function csv_field(s)
  if s:find('[",\n\r]') then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

-- raw_lines: sqlcmd output lines (stdout + stderr merged).
-- Returns a table with:
--   ok        - false when the output is an error message or empty
--   lines     - noise-filtered output lines (for error display)
--   csv_lines - when ok, the result re-encoded as CSV rows
function M.process(raw_lines)
  local lines = {}
  for _, line in ipairs(raw_lines) do
    line = line:gsub("\r", "")
    if not is_noise(line) then
      lines[#lines + 1] = line
    end
  end

  if #lines == 0 then
    return { ok = false, lines = { "Query returned no output" } }
  end

  -- SQL errors and client errors are not tabular output
  if lines[1]:match("^Msg %d+, Level %d+") or lines[1]:match("^Sqlcmd: ") then
    return { ok = false, lines = lines }
  end

  -- Merge continuation lines. With -k 2 embedded newlines are scrubbed from
  -- char columns, but types outside sqlcmd's scrub list (e.g. sql_variant)
  -- can still break a row across physical lines. The header's separator
  -- count says how many separators a complete row must have.
  local expected = count_sep(lines[1])
  local rows = {}
  local cur, cur_n
  for _, line in ipairs(lines) do
    local n = count_sep(line)
    if cur == nil then
      cur, cur_n = line, n
    elseif cur_n < expected then
      -- current row is incomplete: this line continues it
      cur, cur_n = cur .. "\n" .. line, cur_n + n
    elseif n == 0 and expected > 0 then
      -- a line with no separators after a complete row can only be the
      -- rest of that row's last column
      cur = cur .. "\n" .. line
    else
      rows[#rows + 1] = cur
      cur, cur_n = line, n
    end
  end
  rows[#rows + 1] = cur

  local csv_lines = {}
  for _, row in ipairs(rows) do
    local fields = vim.split(row, M.SEP, { plain = true })
    for i, f in ipairs(fields) do
      fields[i] = csv_field(f)
    end
    csv_lines[#csv_lines + 1] = table.concat(fields, ",")
  end

  return { ok = true, lines = lines, csv_lines = csv_lines }
end

return M
