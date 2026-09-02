-- Claude Code session state in the statusline.
--
-- Display side of scripts/claude-nvim-status: that script is a Claude Code hook (registered in
-- ~/.claude/settings.json) which calls `v:lua.ClaudeStatus.set(<state>)` over $NVIM whenever the
-- Claude process started by claudecode.nvim changes state. Loaded from config/options.lua so the
-- global exists before the first statusline redraw.
--
-- States: busy (working, with elapsed time) · question (Claude asks you something) · waiting
-- (permission prompt for a non-edit tool) · diff (edit permission = the diff you accept/deny) ·
-- replied (turn finished; cleared once you look at the terminal) · idle · unsent · nil.
local M = { state = nil, since = nil, hooks_seen = false }

local labels = {
  busy = { text = "󰚩 Claude working", hl = "ClaudeStatusBusy" },
  question = { text = "󰚩 Claude asks a question", hl = "ClaudeStatusAttn" },
  waiting = { text = "󰚩 Claude needs permission", hl = "ClaudeStatusAttn" },
  diff = { text = "󰚩 Claude proposes a diff", hl = "ClaudeStatusDone" },
  replied = { text = "󰚩 Claude replied", hl = "ClaudeStatusDone" },
  idle = { text = "󰚩 Claude idle", hl = "ClaudeStatusIdle" },
  unsent = { text = "󰚩 prompt not submitted, check terminal", hl = "ClaudeStatusAttn" },
}

local function setup_hl()
  local st = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  vim.api.nvim_set_hl(0, "ClaudeStatusBusy", { fg = "#fabd2f", bg = st.bg, bold = true }) -- gruvbox yellow
  vim.api.nvim_set_hl(0, "ClaudeStatusAttn", { fg = "#fb4934", bg = st.bg, bold = true }) -- gruvbox red
  vim.api.nvim_set_hl(0, "ClaudeStatusDone", { fg = "#8ec07c", bg = st.bg, bold = true }) -- gruvbox aqua
  vim.api.nvim_set_hl(0, "ClaudeStatusIdle", { fg = "#928374", bg = st.bg }) -- gruvbox grey
end

local function redraw()
  vim.schedule(function()
    pcall(vim.cmd.redrawstatus, { bang = true })
  end)
end

-- While busy, tick once a second so the elapsed time stays current.
local timer
local function stop_timer()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end
local function start_timer()
  stop_timer()
  timer = vim.uv.new_timer()
  timer:start(1000, 1000, vim.schedule_wrap(function()
    pcall(vim.cmd.redrawstatus, { bang = true })
  end))
end

---State changes that originate inside Neovim (terminal closed, reply acknowledged, no receipt).
---@param state string|nil
function M.set_internal(state)
  M.state = state
  M.since = os.time()
  if state == "busy" then
    start_timer()
  else
    stop_timer()
  end
  redraw()
  return ""
end

---Called by the hook script (`nvim --server $NVIM --remote-expr`), so it must return a value.
---@param state "busy"|"question"|"waiting"|"replied"|"idle"|"closed"
function M.set(state)
  M.hooks_seen = true -- the Claude hooks are configured and reach this instance
  if state == "closed" then
    state = nil
  end
  return M.set_internal(state)
end

---Statusline segment. Used inside `%{% ... %}` so the highlight groups are honoured.
---Drawn only in the active window: with laststatus=2 every window has a statusline, and the
---segment would otherwise repeat in the explorer, diff splits and so on (same trick Neovim's
---default statusline uses for LSP progress).
function M.component()
  if vim.api.nvim_get_current_win() ~= tonumber(vim.g.actual_curwin or -1) then
    return ""
  end
  local l = M.state and labels[M.state]
  if not l then
    return ""
  end
  local text = l.text
  if M.state == "busy" and M.since then
    local s = os.time() - M.since
    text = string.format("%s %d:%02d", text, math.floor(s / 60), s % 60)
  end
  return "%#" .. l.hl .. "#" .. text .. "%*  "
end

M.SEGMENT = "%{%v:lua.ClaudeStatus.component()%}"

---Insert the segment right after the first `%=` of a statusline (or append one).
---@param stl string|nil
function M.inject(stl)
  if not stl or stl == "" then
    return "%<%f %h%w%m%r %=" .. M.SEGMENT
  end
  if stl:find(M.SEGMENT, 1, true) then
    return stl
  end
  local head, tail = stl:match("^(.-%%=)(.*)$")
  if head then
    return head .. M.SEGMENT .. tail
  end
  return stl .. "%=" .. M.SEGMENT
end

_G.ClaudeStatus = M

-- Global statusline: Neovim's default with the Claude segment added. SQL buffers use their own
-- window-local statusline (lua/sql/connection.lua), which includes the segment as well.
vim.o.statusline = M.inject(vim.o.statusline)

local group = vim.api.nvim_create_augroup("claude_status", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_hl })
vim.api.nvim_create_autocmd("VimEnter", { group = group, callback = setup_hl })
setup_hl()

local function is_claude_terminal(buf)
  return vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_get_name(buf):find("claude", 1, true) ~= nil
end

-- Looking at the terminal acknowledges a reply.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(ev)
    if (M.state == "replied" or M.state == "unsent") and is_claude_terminal(ev.buf) then
      M.set_internal("idle")
    end
  end,
})

-- Diff lifecycle from claudecode.nvim: flip to "diff" when one opens (even before the permission
-- hook lands) and back to "working" the moment it is accepted or denied, instead of waiting for
-- Claude's next hook event.
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "ClaudeCodeDiffOpened",
  callback = function()
    M.set_internal("diff")
  end,
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "ClaudeCodeDiffClosed",
  callback = function()
    if M.state == "diff" then
      M.set_internal("busy")
    end
  end,
})

-- The Claude process exited (covers kills and crashes; a clean exit also sends SessionEnd).
vim.api.nvim_create_autocmd("TermClose", {
  group = group,
  callback = function(ev)
    if is_claude_terminal(ev.buf) then
      M.set_internal(nil)
    end
  end,
})

return M
