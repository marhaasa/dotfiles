-- coder/claudecode.nvim is imported via the LazyVim `ai.claudecode` extra (see config/lazy.lua).
-- It speaks the same WebSocket/MCP protocol as the official VS Code extension: Claude sees the
-- current file and visual selection, and every edit it proposes opens as a native diff in Neovim
-- that you accept or reject in place. Uses the `claude` CLI login; no API key.
--
-- Keymaps (from the extra, plus <leader>am / <leader>ae here):
--   <leader>ae  HEADLESS EDIT: types "@file#L1-9 <instruction>" straight into Claude's prompt and
--               submits it. No window is shown; the diff appears when Claude proposes a change.
--   <leader>ac  toggle Claude terminal        <leader>af  focus Claude
--   <leader>ar  resume last session           <leader>aC  continue session
--   <leader>ab  add current buffer as context <leader>as  (visual) send selection
--   <leader>aa  accept proposed diff (:w also accepts)   <leader>ad  deny diff
--   <leader>am  select model
-- This is the only AI plugin in the config (gp.nvim, 99 and sidekick.nvim were retired).
-- The statusline shows Claude's state (working / asks a question / needs permission / replied);
-- see lua/config/claude_status.lua and scripts/claude-nvim-status.

---Headless edit. Deliberately avoids the plugin's at-mention route (ClaudeCodeSend), because that
---re-shows the terminal on every send. Writing to the terminal channel never opens a window.
local function headless_edit()
  local cc = require("claudecode")
  local terminal = require("claudecode.terminal")

  -- Capture the visual range before the input prompt leaves visual mode.
  local line1, line2
  if vim.fn.mode():match("^[vV\22]") then
    line1, line2 = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
    if line1 > line2 then
      line1, line2 = line2, line1
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    vim.notify("Claude: this buffer is not a file on disk", vim.log.levels.WARN)
    return
  end
  -- Claude reads the file from disk, so unsaved changes would be invisible and the accepted diff
  -- would overwrite them. Write without autocmds so format-on-save cannot shift the line numbers.
  if vim.bo.modified then
    vim.cmd("noautocmd silent write")
  end

  -- Same relative-to-cwd formatting the plugin uses for its own mentions; Claude runs in that cwd.
  local ok, rel = pcall(cc._format_path_for_at_mention, file)
  local mention = "@" .. (ok and rel or file) .. (line1 and ("#L" .. line1 .. "-" .. line2) or "")

  vim.ui.input({ prompt = "Claude " .. mention .. " ▸ " }, function(instruction)
    if not instruction or instruction:match("^%s*$") then
      return
    end
    local text = mention .. " " .. instruction

    local function submit()
      local buf = terminal.get_active_terminal_bufnr()
      local chan = buf and vim.api.nvim_buf_is_valid(buf) and (vim.b[buf].terminal_job_id or vim.bo[buf].channel)
      if not chan or chan == 0 then
        vim.notify("Claude: terminal not ready, instruction not sent (see :ClaudeCodeStatus)", vim.log.levels.WARN)
        return
      end
      -- Bracketed paste: the text lands verbatim, so Claude's "@" file autocomplete never opens and
      -- Enter cannot be swallowed by a suggestion popup (typing it char by char did exactly that in
      -- large repos). Enter follows once the paste has been processed.
      local t0 = os.time()
      vim.fn.chansend(chan, "\27[200~" .. text .. "\27[201~")
      vim.defer_fn(function()
        pcall(vim.fn.chansend, chan, "\r")
      end, 150)
      -- Receipt: the Claude hooks report every prompt as "busy". If they are wired up and nothing
      -- comes back, the prompt did not go through; say so in the statusline.
      vim.defer_fn(function()
        local st = _G.ClaudeStatus
        if st and st.hooks_seen and (st.since or 0) < t0 then
          st.set_internal("unsent")
        end
      end, 4000)
    end

    if terminal.get_active_terminal_bufnr() and cc.is_claude_connected() then
      submit()
      return
    end

    -- No running Claude: launch it and hide the window in the same tick, so nothing is drawn.
    if not terminal.get_active_terminal_bufnr() then
      terminal.open()
      terminal.simple_toggle()
      vim.schedule(function()
        vim.cmd("stopinsert")
      end)
    end

    -- The IDE handshake doubles as "prompt is ready": poll for it, then type the instruction.
    local waited, timer = 0, vim.uv.new_timer()
    timer:start(
      500,
      500,
      vim.schedule_wrap(function()
        waited = waited + 500
        if cc.is_claude_connected() then
          timer:stop()
          timer:close()
          vim.defer_fn(submit, 500)
        elseif waited >= 30000 then
          timer:stop()
          timer:close()
          vim.notify("Claude: not connected after 30 s; instruction not sent", vim.log.levels.WARN)
        end
      end)
    )
  end)
end

return {
  "coder/claudecode.nvim",
  opts = {
    -- ~/.claude/settings.json sets defaultMode = "auto", which approves edits without asking.
    -- The in-editor diff is shown as part of the edit approval, so inside Neovim start Claude in
    -- "manual" mode (ask before edits); terminal sessions keep auto mode. Shift+Tab cycles modes.
    terminal_cmd = "claude --permission-mode manual",
    focus_after_send = false,
    terminal = {
      split_side = "right",
      split_width_percentage = 0.35,
      provider = "auto", -- snacks terminal (works even with snacks.terminal `enabled = false`)
    },
    diff_opts = {
      layout = "vertical",
      keep_terminal_focus = false,
    },
  },
  keys = {
    { "<leader>ae", headless_edit, mode = { "n", "x" }, desc = "Claude: headless edit (@context + instruction -> diff)" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
  },
}
