-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
-- Additional completion controls for markdown files
-- Note: Main markdown completion config is in blink.lua, this is a backup
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    -- Additional markdown completion configuration
    vim.opt_local.completeopt = "menu,menuone,noinsert" -- Manual completion trigger only
  end,
})

-- attemting to disable terraform ls on fixture file
-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = "*fixture*",
--   callback = function()
--     vim.diagnostic.disable(0)
--
--     this one also didnt work:     vim.lsp.stop_client(vim.lsp.get_active_clients())
--   end,
-- })

-- wrap and check for spell in text filetypes
-- added to disable spelling
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitcommit", "markdown", "pandoc" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})

-- vim.api.nvim_create_autocmd("filetype", {
--   -- group = augroup("wrap_spell"),
--   pattern = { "pandoc" },
--   command = "PandocFolding none",
-- })

-- Go related

-- Run gofmt + goimport on save

local format_sync_grp = vim.api.nvim_create_augroup("GoImport", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    require("go.format").goimport()
  end,
  group = format_sync_grp,
})

vim.api.nvim_create_autocmd("filetype", {
  -- group = augroup("wrap_spell"),
  pattern = { "go" },
  command = 'lua require("cmp").setup { enabled = true }',
})

--vim.cmd([[autocmd BufWritePre <buffer> lua vim.lsp.buf.format()]])
--local cmp = require("cmp")
--local cmp_action = require("lsp-zero").cmp_action()
-- configure manual  autocompletion
--cmp.setup({
--  mapping = cmp.mapping.preset.insert({
--    -- tab completion
--    ["<Tab>"] = cmp_action.tab_complete(),
--    ["<S-Tab>"] = cmp_action.select_prev_or_fallback(),
--  }),
--})

-- autocmd for .sql files to use poor mans T-SQL formatter on save
--vim.api.nvim_create_autocmd({ "BufWritePre" }, {
--  pattern = "*.sql",
--  command = ":%!sqlformat",
--})

-- Prevent sqls LSP from attaching to SQL files
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "sqls" then
      vim.lsp.buf_detach_client(args.buf, client.id)
      -- Silently detach without notification to avoid spam
    end
  end,
})

-- Suppress sqls connection error messages (patched once to avoid closure chain)
if not vim.g._sqls_notify_patched then
  vim.g._sqls_notify_patched = true
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if type(msg) == "string" and (
      msg:match("sqls.*no database connection") or
      msg:match("LSP%[sqls%]") or
      msg:match("database connection")
    ) then
      return
    end
    return original_notify(msg, level, opts)
  end
end

function _G.extract_tasks_and_remind()
  -- Redirect the output of the :g command to a variable
  vim.cmd("silent! redir => tasks")
  vim.cmd("silent! g/TODO:/p")
  vim.cmd("silent! redir END")

  -- Get the tasks
  local tasks = vim.api.nvim_get_var("tasks")

  -- Print the tasks
  print("Sending the following tasks to reminders CLI:\n" .. tasks)

  -- Pass the tasks to the reminders CLI
  for task in tasks:gmatch("[^\r\n]+") do
    -- Remove the "TODO:" prefix from the task
    local task_without_prefix = task:match("^TODO:%s*(.*)")
    -- Set the category to "Jobb"
    local category = "Jobb"
    -- Check if a due date is provided
    if task_without_prefix:find("tid:") then
      -- Extract the description and due date from the task
      local description, due_date = task_without_prefix:match("(.-)%s*tid:%s*(.*)")
      -- Pass the category, description, and due date to the reminders CLI
      os.execute(string.format("reminders add '%s' '%s' --due-date '%s'", category, description, due_date))
    else
      -- Pass the category and description to the reminders CLI
      os.execute(string.format("reminders add '%s' '%s'", category, task_without_prefix))
    end
  end
end

-- Create an autocmd for BufWinEnter event to remove gray highlighted comments and disable statusline on dashboard
vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = "*",
  callback = function()
    vim.cmd("hi Comment term=bold cterm=NONE ctermfg=Darkgrey ctermbg=NONE gui=NONE guifg=NONE guibg=NONE")
    
    -- Force disable statusline on entry screens while keeping them visible
    if vim.bo.filetype == "lazy" or vim.bo.filetype == "dashboard" or vim.bo.filetype == "alpha" or vim.bo.filetype == "snacks_dashboard" then
      vim.opt_local.laststatus = 0
    end
  end,
})

-- Better markdown settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    -- Only apply if buffer is valid
    if not vim.api.nvim_buf_is_valid(0) then return end
    
    -- Re-enable diagnostics but make them less intrusive
    vim.diagnostic.enable(true)
    vim.diagnostic.config({
      virtual_text = false,
      signs = false,
      underline = false,
      update_in_insert = false,
    })
    
    -- Better text settings - balanced conceal level
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = 'nv'
    
    -- Just disable line-causing elements, let render-markdown handle code blocks
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(0) and vim.bo.filetype == 'markdown' then
        pcall(function()
          vim.cmd('syntax clear markdownRule')
          vim.cmd('syntax clear markdownLineBreak')
        end)
      end
    end)
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.showbreak = '  ↳ '
    
    -- Better folding
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = 'nvim_treesitter#foldexpr()'
    vim.opt_local.foldenable = false
    
    -- Custom wikilink highlighting without icons (with safety check)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(0) and vim.bo.filetype == 'markdown' then
        pcall(function()
          vim.cmd('syntax clear markdownWikiLink')
          vim.cmd('syntax match markdownWikiLink /\\[\\[\\zs.\\{-}\\ze\\]\\]/')
          vim.cmd('highlight link markdownWikiLink Identifier')
        end)
      end
    end)
  end,
})
