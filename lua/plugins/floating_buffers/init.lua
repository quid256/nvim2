-- keeps track of a collection of floating buffers
local FloatingBuffers = { buffers = {} }

function FloatingBuffers:setup(name, opts)
  if self.buffers[name] ~= nil then
    error('Already created buffer with name ' .. name)
  end

  self.buffers[name] = {
    opts = opts or {},
    buf = -1,
    win = -1,
  }
end

function FloatingBuffers:toggle(name)
  local state = self.buffers[name]
  if state == nil then
    error("Can't toggle buffer, DNE: " .. name)
  end

  if not vim.api.nvim_win_is_valid(state.win) then
    local width = state.opts.width or math.floor(vim.o.columns * 0.8)
    local height = state.opts.height or math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    if not vim.api.nvim_buf_is_valid(state.buf) then
      print 'creating'
      state.buf = vim.api.nvim_create_buf(false, true)
      print(state.buf)
    end

    local win_config = vim.tbl_extend('force', {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      border = 'bold',
      title_pos = 'center',
    }, state.opts.win_config or {})

    state.win = vim.api.nvim_open_win(state.buf, true, win_config)

    if state.opts.terminal_buffer then
      -- set this up as a terminal buffer if it isn't set that way already
      if vim.bo[state.buf].buftype ~= 'terminal' then
        vim.cmd.term()
        vim.keymap.set('n', 'q', '<cmd>quit<cr>', {
          buffer = state.buf,
        })
      end
    end
  else
    -- Deletes the window but retain the buffer, as oppose to *_close which would also kill the buffer
    vim.api.nvim_win_hide(state.win)
  end
end

return { FloatingBuffers = FloatingBuffers }
