-- Turns go-sqlcmd tabular output into RFC 4180 CSV for VisiData, one CSV per
-- result set, so a file with several SELECTs yields several grids.
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

-- The dashes row sqlcmd prints under every header
local function is_underline(line)
  return line:match("^[%-\31]+$") ~= nil
end

local function is_noise(line)
  return line == ""
    or is_underline(line)
    or line:match("^%(%d+ rows? affected%)") ~= nil
    or line:match("^%(Rows affected: %d+%)") ~= nil
    or line:match("^Changed database context") ~= nil
    or line:match("^Warning:") ~= nil
    -- Fabric Data Warehouse prints this after every statement:
    -- "Statement ID: {guid} | Query hash: 0x... | Distributed request ID: {guid}"
    or line:match("^Statement ID: {") ~= nil
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

-- Encode one result set (header first, noise already removed) as CSV.
-- Returns { csv_lines, rows, label }: rows is the data row count; label is
-- the value every data row shares in its first column, nil when they differ
-- or there are no rows. A query that tags each SELECT with a constant first
-- column (e.g. '1 sanity' AS block) names its grids this way.
local function encode_set(lines)
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

  local csv_lines, label = {}, nil
  for i, row in ipairs(rows) do
    local fields = vim.split(row, M.SEP, { plain = true })
    if i > 1 then
      if label == nil then
        label = fields[1]
      elseif label ~= fields[1] then
        label = false
      end
    end
    for j, f in ipairs(fields) do
      fields[j] = csv_field(f)
    end
    csv_lines[#csv_lines + 1] = table.concat(fields, ",")
  end
  if not label or label == "" then
    label = nil
  end
  return { csv_lines = csv_lines, rows = #rows - 1, label = label }
end

-- raw_lines: sqlcmd output lines (stdout + stderr merged).
-- Returns a table with:
--   ok     - false when the output is an error message or empty
--   lines  - noise-filtered output lines (for error display)
--   sets   - when ok, one { csv_lines, rows, label } per result set, in order
function M.process(raw_lines)
  local all = {}
  for _, line in ipairs(raw_lines) do
    all[#all + 1] = (line:gsub("\r", ""))
  end

  local lines = {}
  for _, line in ipairs(all) do
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

  -- Every result set starts with its header line followed by an underline
  -- row; split there so each set is encoded against its own header.
  local starts = {}
  for i = 2, #all do
    if is_underline(all[i]) and not is_noise(all[i - 1]) then
      starts[#starts + 1] = i - 1
    end
  end
  if #starts == 0 then
    -- No header/underline pair (e.g. a single unnamed column): one set
    return { ok = true, lines = lines, sets = { encode_set(lines) } }
  end

  local sets = {}
  for k, start in ipairs(starts) do
    local stop = (starts[k + 1] or (#all + 1)) - 1
    local set_lines = {}
    for i = start, stop do
      if not is_noise(all[i]) then
        set_lines[#set_lines + 1] = all[i]
      end
    end
    sets[#sets + 1] = encode_set(set_lines)
  end

  return { ok = true, lines = lines, sets = sets }
end

return M
