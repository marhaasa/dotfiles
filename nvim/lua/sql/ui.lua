-- Shared UI helpers for the SQL workflow
local M = {}

-- Floating window over a list of lines; closes on q/<Esc>. Returns buf, win.
function M.open_float(lines, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end
  vim.bo[buf].modifiable = false

  local width = opts.width or math.floor(vim.o.columns * 0.7)
  local height = opts.height or math.floor(vim.o.lines * 0.3)
  local win_opts = {
    relative = opts.relative or "editor",
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    title = opts.title,
    title_pos = opts.title and "center" or nil,
  }
  if win_opts.relative == "cursor" then
    win_opts.row, win_opts.col = 1, 0
  else
    win_opts.row = math.floor((vim.o.lines - height) / 2)
    win_opts.col = math.floor((vim.o.columns - width) / 2)
  end
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })

  return buf, win
end

-- Visual selection lines when invoked from visual mode, whole buffer otherwise
function M.selection_or_buffer()
  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    return vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  end
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

return M
