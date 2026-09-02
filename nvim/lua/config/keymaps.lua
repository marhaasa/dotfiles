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
-- Title-case the word under the cursor via vim-abolish coercion (crt); textcase.nvim is not installed.
vim.keymap.set("n", "<leader>rlt", "crt", { remap = true, desc = "Convert word to title case" })


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

-- Note-taking keymaps
vim.keymap.set("n", "<leader>zn", create_and_open_new_note, { desc = "Create and open new note" })
-- Following [[wikilinks]] is handled by the markdown-oxide LSP: use `gd` (and `gr` for backlinks).

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
-- 🗃️ DATABASE OPERATIONS (implementation in lua/sql/)
-- ============================================================================

local sql = require("sql")
sql.setup()

vim.keymap.set({ 'n', 'v' }, '<leader>sq', sql.run_query, { desc = "Run SQL query → VisiData" })
vim.keymap.set({ 'n', 'v' }, '<leader>sx', sql.run_script, { desc = "Execute SQL script (supports GO, :setvar)" })
vim.keymap.set('n', '<leader>sv', sql.open_last_result, { desc = "Reopen last SQL result in VisiData" })
vim.keymap.set('n', '<leader>sh', sql.history_picker, { desc = "SQL query history" })
vim.keymap.set('n', '<leader>sd', sql.describe_table, { desc = "Describe SQL table under cursor" })
vim.keymap.set('n', '<leader>sr', sql.clear_schema_cache, { desc = "Refresh SQL schema cache" })
vim.keymap.set('n', '<leader>ss', sql.schema_cache_status, { desc = "Show SQL schema cache status" })

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
-- 🤖 AI INTEGRATION (CLAUDE CODE)
-- ============================================================================

-- claudecode.nvim is the only AI plugin. Its keymaps live under <leader>a and are listed in
-- lua/plugins/claudecode.lua (headless edit: <leader>ae; accept/deny diff: <leader>aa / <leader>ad).

-- ============================================================================
-- 📝 COMMANDS
-- ============================================================================

-- Create user commands for note-taking functions
vim.api.nvim_create_user_command("CreateAndOpenNewNote", create_and_open_new_note, {})
