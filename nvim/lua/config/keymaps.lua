-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- See KEYMAPS.md for a comprehensive reference of all keymaps

-- ============================================================================
-- 🤖 COMPLETION CONTROLS
-- ============================================================================
vim.keymap.set("n", "<leader>ce", '<cmd>lua vim.b.blink_disable = false<cr>', { desc = "Enable blink completion" })
vim.keymap.set("n", "<leader>cd", '<cmd>lua vim.b.blink_disable = true<cr>', { desc = "Disable blink completion" })

-- ============================================================================
-- 🔍 SEARCH & NAVIGATION ENHANCEMENTS
-- ============================================================================

-- Keep cursor centered when scrolling
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })

-- Keep cursor centered when searching
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result and center" })

-- Telescope keymaps (override LazyVim defaults)
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find Files (Custom)" })
vim.keymap.set("n", "<leader>ft", "<cmd>Telescope live_grep<cr>", { desc = "Find Text (Custom)" })
vim.keymap.set("n", "<leader>fs", "<cmd>Telescope symbols<cr>", { desc = "Find Symbols (Custom)" })

-- ============================================================================
-- 📝 TEXT EDITING & FORMATTING
-- ============================================================================

-- Word operations
vim.keymap.set("n", "<leader>wsq", 'ciw""<Esc>P', { desc = "Surround word with quotes" })

-- Text replacement
vim.keymap.set("n", "<leader>rbs", "<cmd>%s/\\//g<CR>", { desc = "Replace backward slashes" })
vim.keymap.set("n", "<leader>rlt", "<cmd>lua require('textcase').current_word('to_title_case')<CR>",
  { desc = "Convert word to title case" })


-- ============================================================================
-- 🛠️ DEVELOPMENT TOOLS
-- ============================================================================

-- LSP controls
vim.keymap.set("n", "<leader>S", "<cmd>LspStop<CR>", { desc = "Stop LSP server" })

-- Go development
vim.keymap.set("n", "<leader>gt", "<cmd>GoTest<CR>", { desc = "Run Go tests" })

-- Note: LazyGit keymap (<leader>lg) defined in lazygit.lua for lazy loading
-- Note: No Neck Pain keymap (<leader>nn) defined in no-neckpain.lua for lazy loading

-- ============================================================================
-- 🎬 CONTENT CREATION
-- ============================================================================
vim.keymap.set("n", "<leader>hy", "i{{< youtube id >}}<Esc>", { desc = "Insert Hugo YouTube shortcode" })

-- ============================================================================
-- 📝 NOTE TAKING (ZETTELKASTEN)
-- ============================================================================

-- Note creation and navigation functions
local function create_and_open_new_note()
  local line = vim.api.nvim_get_current_line()
  local title = line:match("%[%[(.-)%]%]")

  if title then
    local cmd = string.format('scribe new --vim "%s"', title)
    local output = vim.fn.system(cmd)

    -- scribe outputs "Created note: filename.md" - extract the filename
    local filename = output:match("Created note: (.+%.md)")

    if filename then
      filename = filename:gsub("%z", ""):gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1")
      -- Build full path in notes directory
      local notes_dir = vim.fn.expand("~/notes")
      local file_path = notes_dir .. "/" .. filename

      vim.cmd("edit " .. vim.fn.fnameescape(file_path))
      print("Created and opened new note: " .. title)
    else
      print("Failed to create note. Output: " .. output)
    end
  else
    print("No title found between double square brackets")
  end
end

local function yank_and_open_markdown_link()
  -- Get the text inside wikilink brackets [[link]]
  -- Position cursor inside the link, then search for the pattern
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed

  -- Find wikilink at cursor position
  local link_text = nil
  for match in line:gmatch("%[%[(.-)%]%]") do
    local start_pos, end_pos = line:find("%[%[" .. match:gsub("([%.%^%$%(%)%[%]%*%+%-%?])", "%%%1") .. "%]%]")
    if start_pos and col >= start_pos and col <= end_pos then
      link_text = match
      break
    end
  end

  if not link_text or link_text == "" then
    print("No wikilink found at cursor position")
    return
  end

  local scan = require("plenary.scandir")

  -- Search in notes directory first, fall back to current directory
  local notes_dir = vim.fn.expand("~/notes")
  local search_dir = vim.fn.isdirectory(notes_dir) == 1 and notes_dir or vim.loop.cwd()

  -- Build case-insensitive pattern: "abc" -> "[Aa][Bb][Cc]"
  local function case_insensitive_pattern(text)
    return text:gsub(".", function(c)
      if c:match("%a") then
        return "[" .. c:upper() .. c:lower() .. "]"
      elseif c:match("[%.%^%$%(%)%[%]%*%+%-%?]") then
        return "%" .. c -- escape special chars
      else
        return c
      end
    end)
  end

  local pattern = case_insensitive_pattern(link_text)

  local files = scan.scan_dir(search_dir, {
    depth = 10,
    hidden = true,
    add_dirs = false,
    search_pattern = "/" .. pattern .. "%.md$",
  })

  if #files > 0 then
    vim.cmd("edit " .. vim.fn.fnameescape(files[1]))
  else
    print("No file found matching: " .. link_text)
  end
end

-- Note-taking keymaps
vim.keymap.set("n", "<leader>zn", create_and_open_new_note, { desc = "Create and open new note" })
vim.keymap.set("n", "<leader>zo", yank_and_open_markdown_link, { desc = "Open note from link" })

-- sage command
vim.api.nvim_create_user_command('SageTag', function()
  local file = vim.fn.expand('%:p')
  vim.fn.system('sage file --quiet "' .. file .. '"')
  vim.cmd('edit') -- Reload the file
end, {})

-- sage keymaps
vim.keymap.set('n', '<leader>zt', function()
  vim.cmd('SageTag')
end, { desc = 'Run SageTag on current file' })

-- ============================================================================
-- 🗃️ DATABASE OPERATIONS
-- ============================================================================

-- Resolve the SQL server, prompting for a 1Password item when SQLSERVER is unset
local function ensure_sqlserver()
  local server = os.getenv("SQLSERVER")
  if server and server ~= "" then
    return server
  end

  local item = vim.fn.input("SQLSERVER not set. 1Password item (empty to cancel): ")
  vim.api.nvim_echo({ { "" } }, false, {})
  if item == "" then
    return nil
  end

  local result = vim.fn.system({ "op", "read", "op://Crayon/" .. item .. "/credential" })
  if vim.v.shell_error ~= 0 or vim.trim(result) == "" then
    vim.api.nvim_echo({ { "Failed to read '" .. item .. "' from 1Password", "ErrorMsg" } }, false, {})
    return nil
  end

  -- Persist for the rest of this nvim session so we only prompt once
  vim.env.SQLSERVER = vim.trim(result)
  return vim.env.SQLSERVER
end

local function run_sql_query()
  local lines
  local mode = vim.api.nvim_get_mode().mode
  
  if mode == 'v' or mode == 'V' or mode == '\22' then -- visual modes
    -- Get visually selected lines
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1
    local end_line = end_pos[2]
    lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  else
    -- Get all lines from buffer
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end
  
  local query = table.concat(lines, ' '):gsub('"', '\\"'):gsub('%s+', ' ')

  -- Build sqlcmd command
  local server = ensure_sqlserver()
  if not server then
    vim.api.nvim_echo({ { "SQL query cancelled: no server", "WarningMsg" } }, false, {})
    return
  end
  local db = os.getenv("SQLDB") or "DW"
  local auth = os.getenv("SQLAUTH") or "-G"

  local cmd = { "sqlcmd", "-S", server, "-d", db, auth, "-Q", query, "-s", "|", "-W" }

  -- Test if sqlcmd exists first
  if vim.fn.executable("sqlcmd") == 0 then
    print("Error: sqlcmd not found in PATH")
    return
  end

  -- Progress tracking
  local start_time = vim.loop.now()
  local progress_timer
  local job_id

  -- Show initial message
  vim.api.nvim_echo({ { "Running SQL query...", "Normal" } }, false, {})

  local function update_progress()
    local elapsed = (vim.loop.now() - start_time) / 1000
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    local time_str = mins > 0 and string.format("%dm %02ds", mins, secs) or string.format("%ds", secs)

    vim.schedule(function()
      vim.api.nvim_echo({
        { "SQL query running... ",     "Normal" },
        { time_str,                    "Number" },
        { " (Press Ctrl+C to cancel)", "Comment" }
      }, false, {})
    end)
  end

  -- Start progress timer (update every second)
  progress_timer = vim.loop.new_timer()
  progress_timer:start(1000, 1000, update_progress)

  local result_lines = {}
  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(result_lines, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(result_lines, data)
      end
    end,
    on_exit = function(_, code)
      -- Stop progress tracking
      if progress_timer then
        progress_timer:stop()
        progress_timer:close()
      end

      local elapsed = (vim.loop.now() - start_time) / 1000
      local mins = math.floor(elapsed / 60)
      local secs = math.floor(elapsed % 60)
      local time_str = mins > 0 and string.format("%dm %02ds", mins, secs) or string.format("%.1fs", secs)

      vim.schedule(function()
        if code ~= 0 then
          vim.api.nvim_echo({ { "Query cancelled or failed after ", "Normal" }, { time_str, "Number" } }, false, {})
        else
          vim.api.nvim_echo({ { "Query completed in ", "Normal" }, { time_str, "Number" } }, false, {})
        end

        -- Filter out empty lines and unwanted rows
        local raw_lines = {}
        for _, line in ipairs(result_lines) do
          line = line:gsub("\r", "") -- strip Windows CR from SQL Server output
          if line ~= ""
            and not line:match("^%-+")                        -- separator rows (----|----)
            and not line:match("^%(%d+ rows affected%)")      -- row count footer
            and not line:match("^Changed database context")   -- sqlcmd info messages
            and not line:match("^Warning:")                   -- sqlcmd warnings
          then
            table.insert(raw_lines, line)
          end
        end

        -- Merge continuation lines caused by embedded newlines in data values.
        -- The header determines the expected number of separators per row; any
        -- subsequent line with fewer separators is a continuation of the previous row.
        local clean_lines = {}
        if #raw_lines > 0 then
          local function count_sep(s)
            local _, n = s:gsub("|", "")
            return n
          end
          local expected = count_sep(raw_lines[1])
          table.insert(clean_lines, raw_lines[1])
          for i = 2, #raw_lines do
            local line = raw_lines[i]
            if count_sep(line) < expected then
              -- continuation: embedded newline in a data value — join with space
              clean_lines[#clean_lines] = clean_lines[#clean_lines] .. " " .. line
            else
              table.insert(clean_lines, line)
            end
          end
        end

        -- Check for errors
        if code ~= 0 or #clean_lines == 0 or clean_lines[1]:match("Msg") or clean_lines[1]:match("Error") then
          -- Show error in floating window
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, clean_lines)
          vim.bo[buf].filetype = "sql"

          local width = math.floor(vim.o.columns * 0.7)
          local height = math.floor(vim.o.lines * 0.3)
          local row = math.floor((vim.o.lines - height) / 2)
          local col = math.floor((vim.o.columns - width) / 2)

          local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            border = "rounded",
            style = "minimal",
          })

          vim.keymap.set("n", "q", function()
            vim.api.nvim_win_close(win, true)
          end, { buffer = buf })
        else
          -- Success: write TSV and open VisiData
          local tmp = vim.fn.tempname() .. ".psv"
          local f = io.open(tmp, "w")
          for _, line in ipairs(clean_lines) do
            f:write(line .. "\n")
          end
          f:close()

          -- Open VisiData in terminal (replaces current window buffer)
          local term_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_win_set_buf(0, term_buf)

          vim.fn.termopen({ "vd", "-f", "psv", tmp }, {
            on_exit = function()
              os.remove(tmp)
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(term_buf) then
                  vim.api.nvim_buf_delete(term_buf, { force = true })
                end
              end)
            end
          })
          vim.cmd("startinsert")
        end
      end)
    end
  })

  -- Allow cancelling with Ctrl+C
  vim.keymap.set('n', '<C-c>', function()
    if job_id then
      vim.fn.jobstop(job_id)
      if progress_timer then
        progress_timer:stop()
        progress_timer:close()
      end
      vim.api.nvim_echo({ { "SQL query cancelled", "WarningMsg" } }, false, {})
    end
  end, { buffer = 0, desc = "Cancel SQL query" })
end

-- Open a scratch SQL buffer (reuses /tmp/scratch.sql)
vim.api.nvim_create_user_command("Sql", function()
  local path = "/tmp/scratch.sql"
  -- Remove stale swap file to avoid the swap dialog blocking input
  local swap = vim.fn.swapname(path)
  if swap and swap ~= "" and vim.fn.filereadable(swap) == 1 then
    os.remove(swap)
  end
  vim.cmd("edit " .. path)
end, { desc = "Open scratch SQL buffer" })

vim.keymap.set('n', '<leader>sq', run_sql_query, { desc = "Run entire buffer as SQL query with sqlcmd → VisiData" })
vim.keymap.set('v', '<leader>sq', run_sql_query, { desc = "Run visual selection as SQL query with sqlcmd → VisiData" })

local function run_sql_script()
  -- Get buffer content (entire buffer or visual selection)
  local lines
  local mode = vim.api.nvim_get_mode().mode

  if mode == 'v' or mode == 'V' or mode == '\22' then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1
    local end_line = end_pos[2]
    lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  else
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  -- Write to temp file (preserving line breaks for GO statements)
  local tmp = vim.fn.tempname() .. ".sql"
  local f = io.open(tmp, "w")
  for _, line in ipairs(lines) do
    f:write(line .. "\n")
  end
  f:close()

  -- Build sqlcmd command with -i (input file) instead of -Q
  local server = ensure_sqlserver()
  if not server then
    os.remove(tmp)
    vim.api.nvim_echo({ { "SQL script cancelled: no server", "WarningMsg" } }, false, {})
    return
  end
  local db = os.getenv("SQLDB") or "DW"
  local auth = os.getenv("SQLAUTH") or "-G"

  local cmd = { "sqlcmd", "-S", server, "-d", db, auth, "-i", tmp }

  if vim.fn.executable("sqlcmd") == 0 then
    print("Error: sqlcmd not found in PATH")
    os.remove(tmp)
    return
  end

  -- Progress tracking
  local start_time = vim.loop.now()
  local progress_timer
  local job_id

  vim.api.nvim_echo({ { "Running SQL script...", "Normal" } }, false, {})

  local function update_progress()
    local elapsed = (vim.loop.now() - start_time) / 1000
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    local time_str = mins > 0 and string.format("%dm %02ds", mins, secs) or string.format("%ds", secs)

    vim.schedule(function()
      vim.api.nvim_echo({
        { "SQL script running... ",     "Normal" },
        { time_str,                     "Number" },
        { " (Press Ctrl+C to cancel)",  "Comment" }
      }, false, {})
    end)
  end

  progress_timer = vim.loop.new_timer()
  progress_timer:start(1000, 1000, update_progress)

  local result_lines = {}
  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(result_lines, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(result_lines, data)
      end
    end,
    on_exit = function(_, code)
      if progress_timer then
        progress_timer:stop()
        progress_timer:close()
      end

      -- Clean up temp file
      os.remove(tmp)

      local elapsed = (vim.loop.now() - start_time) / 1000
      local mins = math.floor(elapsed / 60)
      local secs = math.floor(elapsed % 60)
      local time_str = mins > 0 and string.format("%dm %02ds", mins, secs) or string.format("%.1fs", secs)

      vim.schedule(function()
        -- Filter empty lines
        local clean_lines = {}
        for _, line in ipairs(result_lines) do
          if line ~= "" then
            table.insert(clean_lines, line)
          end
        end

        -- Show results in floating window
        local buf = vim.api.nvim_create_buf(false, true)

        -- Add status header
        local status_msg = code == 0
          and { "Script completed successfully in " .. time_str, "" }
          or { "Script failed (exit code " .. code .. ") after " .. time_str, "" }

        local display_lines = vim.list_extend(status_msg, clean_lines)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
        vim.bo[buf].filetype = "sql"
        vim.bo[buf].modifiable = false

        local width = math.min(math.floor(vim.o.columns * 0.8), 120)
        local height = math.min(math.floor(vim.o.lines * 0.6), #display_lines + 2)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = row,
          col = col,
          border = "rounded",
          style = "minimal",
          title = code == 0 and " Script Output " or " Script Error ",
          title_pos = "center",
        })

        -- Highlight status line
        if code == 0 then
          vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticOk", 0, 0, -1)
        else
          vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticError", 0, 0, -1)
        end

        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })

        vim.keymap.set("n", "<Esc>", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })
      end)
    end
  })

  -- Allow cancelling with Ctrl+C
  vim.keymap.set('n', '<C-c>', function()
    if job_id then
      vim.fn.jobstop(job_id)
      if progress_timer then
        progress_timer:stop()
        progress_timer:close()
      end
      os.remove(tmp)
      vim.api.nvim_echo({ { "SQL script cancelled", "WarningMsg" } }, false, {})
    end
  end, { buffer = 0, desc = "Cancel SQL script" })
end

vim.keymap.set('n', '<leader>sx', run_sql_script, { desc = "Execute SQL script (supports GO, :setvar)" })
vim.keymap.set('v', '<leader>sx', run_sql_script, { desc = "Execute SQL script selection (supports GO, :setvar)" })

-- SQL schema cache management
vim.keymap.set('n', '<leader>sr', function()
  local sql_schema = require('utils.sql_schema')
  sql_schema.clear_cache()
  print("SQL schema cache cleared")
end, { desc = "Refresh SQL schema cache" })

vim.keymap.set('n', '<leader>ss', function()
  local sql_schema = require('utils.sql_schema')
  local status = sql_schema.get_cache_status()
  print("SQL Cache Status:")
  print("Connection: " .. status.connection)
  print("Tables cached: " .. status.tables_count)
  print("Column sets cached: " .. status.columns_count)
  if status.tables_age then
    print("Tables cache age: " .. status.tables_age .. "s")
  end
end, { desc = "Show SQL schema cache status" })

-- SQL completion trigger (only in SQL files)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sql",
  callback = function()
    vim.keymap.set('i', '<C-Space>', function()
      local blink = require('blink.cmp')
      if blink.is_visible() then
        blink.hide()
      else
        blink.show()
      end
    end, { desc = "Toggle SQL completion", buffer = true })
  end,
})

-- SSDT table formatter (formats CREATE TABLE statements to Visual Studio style)
local ssdt_formatter = vim.fn.expand("~/Repos/github.com/marhaasa/dotfiles/scripts/ssdt_table_formatter.py")
vim.keymap.set('n', '<leader>sf', function()
  if vim.fn.filereadable(ssdt_formatter) == 0 then
    print("Error: ssdt_table_formatter.py not found")
    return
  end
  vim.cmd("%!python3 " .. ssdt_formatter)
end, { desc = "Format SQL table (SSDT style)" })

-- QoL: auto-enter terminal mode when opening any :terminal buffer
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.cmd("startinsert")
  end
})

-- QoL: <C-q> to leave terminal and return to prev window
vim.keymap.set('t', '<C-q>', [[<C-\><C-n><C-w>p]], { noremap = true, silent = true })





-- ============================================================================
-- 🤖 AI INTEGRATION (GP.NVIM)
-- ============================================================================

-- GP.nvim keymaps are defined in gp.lua plugin file due to their complexity
-- and tight integration with the plugin configuration. They use <C-g> prefix.
-- See KEYMAPS.md for full reference of all GP.nvim keymaps.

-- ============================================================================
-- 📝 COMMANDS
-- ============================================================================

-- Create user commands for note-taking functions
vim.api.nvim_create_user_command("CreateAndOpenNewNote", create_and_open_new_note, {})
vim.api.nvim_create_user_command("YankAndSearchMarkdownLink", yank_and_open_markdown_link, {})
