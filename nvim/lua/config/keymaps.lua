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
    local file_path = output:match("New note created: (.+)")

    if file_path then
      file_path = file_path:gsub("%z", ""):gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1")
      vim.cmd("badd " .. vim.fn.fnameescape(file_path))
      local bufnr = vim.fn.bufnr(file_path)
      vim.api.nvim_set_current_buf(bufnr)
      print("Created and opened new note: " .. title)
    else
      print("Failed to create note: " .. title)
    end
  else
    print("No title found between double square brackets")
  end
end

local function yank_and_open_markdown_link()
  vim.cmd("normal! yi]")
  local yanked_text = vim.fn.getreg('"')
  yanked_text = yanked_text:gsub("%[%[(.-)%]%]", "%1")

  if yanked_text == "" then
    print("No text found inside brackets")
    return
  end

  local scan = require("plenary.scandir")

  -- Search in notes directory first, fall back to current directory
  local notes_dir = vim.fn.expand("~/notes")
  local search_dir = vim.fn.isdirectory(notes_dir) == 1 and notes_dir or vim.loop.cwd()

  -- Properly escape all special characters for Lua patterns
  local function escape_pattern(text)
    -- Escape all Lua pattern special characters
    return text:gsub("([%.%^%$%(%)%[%]%*%+%-%?])", "%%%1")
  end

  local escaped_text = escape_pattern(yanked_text)

  local files = scan.scan_dir(search_dir, {
    depth = 5,
    hidden = true,
    add_dirs = false,
    search_pattern = ".*" .. escaped_text .. ".*%.md$",
  })

  if #files > 0 then
    vim.cmd("edit " .. vim.fn.fnameescape(files[1]))
  else
    print("No file found matching: " .. yanked_text)
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


vim.keymap.set('n', '<leader>sq', function()
  -- Get all lines from buffer and build query
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local query = table.concat(lines, ' '):gsub('"', '\\"'):gsub('%s+', ' ')

  -- Build sqlcmd command
  local server = os.getenv("SQLSERVER") or "localhost"
  local db = os.getenv("SQLDB") or "DW"
  local auth = os.getenv("SQLAUTH")

  local cmd = { "sqlcmd", "-S", server, "-d", db }
  if auth and auth ~= "" then table.insert(cmd, auth) end
  vim.list_extend(cmd, { "-Q", query, "-s", ",", "-W" })

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
        local clean_lines = {}
        for _, line in ipairs(result_lines) do
          if line ~= "" and not line:match("^%-+") and not line:match("^%(%d+ rows affected%)$") then
            table.insert(clean_lines, line)
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
          -- Success: write CSV and open VisiData
          local tmp = vim.fn.tempname() .. ".csv"
          local f = io.open(tmp, "w")
          for _, line in ipairs(clean_lines) do
            f:write(line .. "\n")
          end
          f:close()

          -- Open VisiData in terminal
          local term_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_win_set_buf(0, term_buf)
          vim.api.nvim_buf_set_option(term_buf, 'swapfile', false)

          vim.fn.termopen({ "vd", "-f", "csv", tmp }, {
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
end, { desc = "Run entire buffer as SQL query with sqlcmd → VisiData" })

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
