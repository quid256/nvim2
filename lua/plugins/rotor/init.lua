local M = {}

---@class RotorSettings
local default_settings = {
  ---@type string[]
  disabled_buftypes = { 'nofile', 'nowrite', 'quickfix' },

  ---@type string[]
  always_expand_matching = {
    '^_*init_*%.[a-zA-Z0-9]+$',
  },

  ---@type {[string]: any}
  win_config = {
    -- border = ' ', -- or 'rounded', 'double'
    border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
    title = ' buffers ',
    title_pos = 'center',
    style = 'minimal', -- Minimal styling
  },
}

local state = {
  -- Current settings, modified after setup()
  ---@type RotorSettings
  settings = default_settings,

  -- Flag to indicate if the floating window is currently open
  ---@type boolean
  is_switcher_active = false,

  -- Flag for whether a switch is happening right now
  is_switching_now = false,

  -- The buffer and window IDs
  ---@type integer
  floating_buf_id = -1,

  ---@type integer
  floating_win_id = -1,

  -- Global list to store buffer IDs in Most Recently Used (MRU) order
  -- Most recent buffer is at index 1. This list is always live.
  ---@type integer[]
  mru_list = {},

  ---A list of the bufids that should be added to the rotor list. This list's order
  ---remains constant for as long as a the rotor window is open
  ---@type integer[]
  cached_buffer_list = {},
}

-- Create a namespace for our extmarks when the module is loaded
-- This ensures a valid namespace ID is always available for extmarks.
local extmark_ns_id = vim.api.nvim_create_namespace 'RotorBufferHighlight'

-- Define a highlight group for the current buffer line
-- Link it to an existing highlight group for easy styling
vim.api.nvim_set_hl(0, 'RotorSelectedLine', { link = 'PmenuSel' }) -- Or "Visual", "Search" etc.

--- Updates the Most Recently Used (MRU) list.
-- Moves the given buffer ID to the front of the list.
-- This global mru_list is always kept live and used for sorting
-- when the floating window is *initially* opened.
-- @param buf_id number: The ID of the buffer that was just entered.
local function update_mru_list()
  local buf_id = vim.api.nvim_get_current_buf()

  -- Remove buf_id if it's already in the list
  for i, id in ipairs(state.mru_list) do
    if id == buf_id then
      table.remove(state.mru_list, i)
      break
    end
  end
  -- Add buf_id to the front of the list
  table.insert(state.mru_list, 1, buf_id)

  -- Clean up MRU list: remove IDs of invalid/deleted buffers
  local cleaned_mru_list = {}
  for _, id in ipairs(state.mru_list) do
    if vim.api.nvim_buf_is_valid(id) then
      table.insert(cleaned_mru_list, id)
    end
  end
  state.mru_list = cleaned_mru_list
end

-- Set up an autocommand to update the MRU list whenever a buffer is entered
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('RotorMRU', { clear = true }),
  callback = function()
    -- Only update the MRU list if the switch happened from something else other
    -- than using Rotor
    if not state.is_switching_now then
      update_mru_list()
    end
  end,
})

---Writes a list of buffers, sorted by MRU, to cached_buffer_list
local function cache_buffer_list()
  state.cached_buffer_list = {}
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      local buflisted = vim.bo[buf_id].buflisted
      local buftype = vim.bo[buf_id].buftype

      -- Filter out unlisted, scratch, nowrite buffers
      if buflisted and not vim.list_contains(state.settings.disabled_buftypes, buftype) then
        table.insert(state.cached_buffer_list, buf_id)
      end
    end
  end

  ---Map from bufid to mru pos
  ---@type table<integer, integer>
  local mru_pos = {}
  local i = 1
  while i <= #state.mru_list do
    if not vim.list_contains(state.cached_buffer_list, state.mru_list[i]) then
      -- Remove buffers from the MRU list when they no longer show up here
      table.remove(state.mru_list, i)
    else
      mru_pos[state.mru_list[i]] = i
      i = i + 1
    end
  end

  -- Sort buffers by MRU order
  table.sort(state.cached_buffer_list, function(a, b)
    local pos_a = mru_pos[a] or math.huge -- Assign high value if not in MRU (e.g., new buffer)
    local pos_b = mru_pos[b] or math.huge

    if pos_a ~= pos_b then
      return pos_a < pos_b
    else
      return a < b
    end
  end)
end

---@param buf_ids integer[]
---@return table<integer, {components: string[], short_path: string, index: integer}>
local function get_short_unique_filepaths(buf_ids)
  -- 1. Get full filepaths for all buffers

  ---@type table<integer, {components: string[], short_path: string, index: integer}>
  local bufid_to_data = {}

  for _, buf_id in ipairs(buf_ids) do
    local full_path = vim.api.nvim_buf_get_name(buf_id)

    if not full_path or full_path == '' then
      full_path = '[No Name]'
    end

    local components = vim.split(full_path, '[\\/]')
    bufid_to_data[buf_id] = {
      components = components,
      short_path = components[#components],
      index = #components,
    }
  end

  -- 3. Resolve duplicates by adding parent directories
  local counter = 0
  while counter < 10 do
    -- Identify buffers w/ duplicate names
    local potentially_duplicated_paths = {}
    local counts = {}
    for _, data in pairs(bufid_to_data) do
      counts[data.short_path] = (counts[data.short_path] or 0) + 1
    end

    for id, data in pairs(bufid_to_data) do
      local should_expand = false
      for _, pat in ipairs(state.settings.always_expand_matching) do
        if string.match(data.short_path, pat) then
          should_expand = true
          break
        end
      end

      if (should_expand or counts[data.short_path] > 1) and data.index > 1 then
        table.insert(potentially_duplicated_paths, id)
      end
    end

    -- Break here if all the paths were unique
    if #potentially_duplicated_paths == 0 then
      break
    end

    -- Add parent dirs of all the duplicate'd ones
    for _, id_to_fix in ipairs(potentially_duplicated_paths) do
      local data = bufid_to_data[id_to_fix]
      data.index = data.index - 1
      data.short_path = data.components[data.index] .. '/' .. data.short_path
    end
    counter = counter + 1
  end
  if counter == 10 then
    error 'oh no, counter reached 10, something bad has happened'
  end

  return bufid_to_data
end

---@return {lines: string[], highlight_line: integer, max_width: integer}
local function get_content()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_line_idx = -1
  local content_lines = {}
  local max_content_width = 0

  local buf_names = get_short_unique_filepaths(state.cached_buffer_list)

  for i, buf_id in ipairs(state.cached_buffer_list) do
    -- local prefix = buf_id == current_buf and '  ' or '   '
    local prefix = buf_id == current_buf and ' ' or ' '
    local suffix = buf_id == current_buf and ' ' or ' '
    local line_text = string.format('%s%s%s', prefix, buf_names[buf_id].short_path, suffix)
    table.insert(content_lines, line_text)

    if buf_id == current_buf then
      current_line_idx = i
    end

    max_content_width = math.max(max_content_width, vim.fn.strwidth(line_text))
  end

  for i, line in ipairs(content_lines) do
    content_lines[i] = line .. string.rep(' ', max_content_width - #line)
  end

  -- If no relevant buffers are found, display a message
  if #content_lines == 0 then
    table.insert(content_lines, ' No relevant buffers loaded ')
    max_content_width = vim.fn.strwidth(content_lines[1])
  end

  return {
    lines = content_lines,
    highlight_line = current_line_idx,
    max_width = max_content_width,
  }
end

local function close_window()
  -- Close existing buffer/window if it's open, to recreate with new content/size
  if vim.api.nvim_win_is_valid(state.floating_win_id) then
    vim.api.nvim_win_close(state.floating_win_id, true)
  end
  if vim.api.nvim_buf_is_valid(state.floating_buf_id) then
    -- Clear existing extmarks before deleting the old buffer
    vim.api.nvim_buf_clear_namespace(state.floating_buf_id, extmark_ns_id, 0, -1)
    vim.api.nvim_buf_delete(state.floating_buf_id, { force = true })
  end
end

local function ensure_window_visible()
  local content = get_content()

  -- Clear the autocmds that make the window invisible, so nothing can kill the window in
  -- the process of updating it
  local augroup = vim.api.nvim_create_augroup('RotorWindowClose', { clear = true })

  if not vim.api.nvim_buf_is_valid(state.floating_buf_id) then
    state.floating_buf_id = vim.api.nvim_create_buf(false, true)
  end

  local bufopts = vim.bo[state.floating_buf_id]

  -- Set buffer contents
  bufopts.modifiable = true
  vim.api.nvim_buf_set_lines(state.floating_buf_id, 0, -1, false, content.lines)

  -- Set buffer options
  bufopts.buftype = 'nofile'
  bufopts.bufhidden = 'wipe'
  bufopts.swapfile = false
  bufopts.modifiable = false

  -- Get window dimensions
  local win_width = vim.api.nvim_win_get_width(0)
  local win_height = vim.api.nvim_win_get_height(0)

  -- Calculate desired buffer dimensions and position
  local min_width = 10 -- Minimum width
  local max_display_width = 70 -- Max width of the floating window content
  local width = math.min(max_display_width, math.max(min_width, content.max_width))
  local height = math.min(win_height - 2, #content.lines + 2)

  -- Position at top-right
  local row = 0
  local col = win_width - 4
  -- local row = math.floor((win_height - height) / 2)
  -- local col = math.floor((win_width - width) / 2)
  --
  -- Create the floating window configuration
  local win_config = {
    relative = 'win',
    row = row,
    col = col,
    width = width,
    height = height,
  }

  if vim.api.nvim_win_is_valid(state.floating_win_id) then
    vim.api.nvim_win_set_config(state.floating_win_id, win_config)
    vim.api.nvim_win_set_buf(state.floating_win_id, state.floating_buf_id)
  else
    -- Open the floating window without focusing it (second arg is false)
    state.floating_win_id = vim.api.nvim_open_win(
      state.floating_buf_id,
      false,
      vim.tbl_extend('error', state.settings.win_config, {
        anchor = 'NE', -- North-East anchor for top-right positioning
        -- anchor = 'NW', -- North-East anchor for top-right positioning
        focusable = false, -- Make it non-focusable so it doesn't steal focus
        noautocmd = true, -- Prevent autocommands from firing on window creation
      }, win_config)
    )
  end
  -- nvim_win_set_hl_ns({window},
  -- Set highlight for the border
  vim.wo[state.floating_win_id].winhighlight =
    'Normal:TelescopeResultsNormal,FloatBorder:TelescopeResultsBorder,FloatTitle:TelescopeResultsTitle'
  -- vim.wo[state.floating_win_id].winblend = 50

  if content.highlight_line ~= 0 then
    -- Apply highlight to the current buffer's line using extmark
    vim.api.nvim_buf_set_extmark(
      state.floating_buf_id,
      extmark_ns_id,
      content.highlight_line - 1,
      0,
      {
        hl_group = 'RotorSelectedLine',
        end_row = content.highlight_line,
        end_col = 0,
      }
    )
  end

  vim.defer_fn(function()
    vim.api.nvim_create_autocmd({
      'CursorMoved',
      'CursorMovedI',
      'TextChanged',
      'TextChangedP',
      'InsertEnter',
      'BufLeave',
      'CmdlineEnter',
    }, {
      group = augroup,
      callback = function()
        -- Only close if the window is still valid (i.e., not already closed by another trigger)
        if not state.is_switching_now and state.is_switcher_active then
          -- Close the window
          close_window()

          -- Clear the autocommand group after closing
          vim.api.nvim_clear_autocmds { group = 'RotorWindowClose' }

          -- Reset the active flag and cached info when closing the window
          state.is_switcher_active = false
          state.cached_buffer_list = {}

          -- Update MRU list to have this buffer we've arrived at as the target
          update_mru_list()
        end
      end,
    })
  end, 50) -- A small delay (e.g., 50ms)
end

--- Opens the floating buffer with the buffer list content after switching buffers.
-- @param direction string: "next" or "prev" to indicate buffer switch direction.
local function open_buffer_list_buffer(direction)
  -- If switcher isn't already active, write down the current MRU ordering of the buffers
  -- and mark as active
  if not state.is_switcher_active then
    state.is_switcher_active = true
    cache_buffer_list()
  end

  -- Find the index of the current buffer in our cached list
  local current_buf_id = vim.api.nvim_get_current_buf()
  local current_idx = -1
  for i, buf_id in ipairs(state.cached_buffer_list) do
    if buf_id == current_buf_id then
      current_idx = i
      break
    end
  end

  -- Figure out what index should be next after this keypress
  local next_idx
  if current_idx == -1 then
    next_idx = 1
  elseif direction == 'next' then
    next_idx = (current_idx % #state.cached_buffer_list) + 1
  elseif direction == 'prev' then
    next_idx = math.max(current_idx - 1, 1)
  end
  local target_buf_id = state.cached_buffer_list[next_idx]

  -- Switch to the target buffer if it's different than the current one
  if target_buf_id ~= current_buf_id then
    state.is_switching_now = true
    vim.api.nvim_set_current_buf(target_buf_id)
    state.is_switching_now = false
  end

  -- Make sure the switcher window is visible
  ensure_window_visible()
end

function M.next()
  assert(state.settings ~= nil, 'Must call setup first')
  open_buffer_list_buffer 'next'
end

function M.prev()
  assert(state.settings ~= nil, 'Must call setup first')
  open_buffer_list_buffer 'prev'
end

---Sets up Rotor. Doesn't need to be called if you're not going to override any defaults
---@param opts nil | RotorSettings
function M.setup(opts)
  state.settings = vim.tbl_deep_extend('force', default_settings, opts or {})
end

return M
