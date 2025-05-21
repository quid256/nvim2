-- This Lua code creates a small floating buffer in Neovim that appears
-- at the top-right of the screen whenever 'Alt-j' or 'Alt-k' is pressed.
-- 'Alt-l' switches to the next RELEVANT buffer (MRU sorted), and 'Alt-h' switches to the previous.
-- The buffer displays a list of relevant buffers, highlighting the current one.
-- The MRU order displayed remains constant as long as the window is open.
-- The buffer will close automatically when any other key is pressed.

local M = {} -- Module table for organization

-- Define a highlight group for the current buffer line
-- Link it to an existing highlight group for easy styling
vim.api.nvim_set_hl(0, 'RotorSelectedLine', { link = 'Search' }) -- Or "Visual", "Search" etc.

local disabled_buftypes = {
  nofile = true,
  nowrite = true,
  quickfix = true,
}

-- Create a namespace for our extmarks when the module is loaded
-- This ensures a valid namespace ID is always available for extmarks.
local extmark_ns_id = vim.api.nvim_create_namespace 'RotorBufferHighlight'

-- Flag to indicate if the floating window is currently open
local is_switcher_active = false

-- Flag for whether a switch is happening right now
local is_switching_now = false

-- The buffer and window IDs
local floating_buf_id = -1
local floating_win_id = -1

-- Global list to store buffer IDs in Most Recently Used (MRU) order
-- Most recent buffer is at index 1. This list is always live.
local mru_list = {}

--- Updates the Most Recently Used (MRU) list.
-- Moves the given buffer ID to the front of the list.
-- This global mru_list is always kept live and used for sorting
-- when the floating window is *initially* opened.
-- @param buf_id number: The ID of the buffer that was just entered.
local function update_mru_list()
  local buf_id = vim.api.nvim_get_current_buf()

  -- Remove buf_id if it's already in the list
  for i, id in ipairs(mru_list) do
    if id == buf_id then
      table.remove(mru_list, i)
      break
    end
  end
  -- Add buf_id to the front of the list
  table.insert(mru_list, 1, buf_id)

  -- Clean up MRU list: remove IDs of invalid/deleted buffers
  local cleaned_mru_list = {}
  for _, id in ipairs(mru_list) do
    if vim.api.nvim_buf_is_valid(id) then
      table.insert(cleaned_mru_list, id)
    end
  end
  mru_list = cleaned_mru_list
end

-- Set up an autocommand to update the MRU list whenever a buffer is entered
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('FloatingBufferMRU', { clear = true }),
  callback = function()
    -- Only update the MRU list if the switch happened from something else other
    -- than using Rotor
    if not is_switching_now then
      update_mru_list()
    end
  end,
})

-- Cache for the buffers_info list. This list's ORDER remains constant
-- while the floating window is active.
local cached_buffer_list = {}

--- Gets information about relevant buffers (not hidden), sorted by MRU.
-- Relevant buffers are defined as:
-- - buflisted = true (appears in :ls)
-- - buftype is not 'nofile' (scratch), 'nowrite' (e.g., help), or 'terminal'
-- This function always returns a freshly sorted list based on the current mru_list.
-- @return table: A list of tables, each containing {buf_id, name, is_current}
local function cache_buffer_list()
  cached_buffer_list = {}
  local current_buf_id = vim.api.nvim_get_current_buf()

  -- Iterate over all loaded buffers
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    -- Check if the buffer is valid before proceeding
    if vim.api.nvim_buf_is_valid(buf_id) then
      local buflisted = vim.api.nvim_get_option_value('buflisted', { buf = buf_id })
      local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf_id })

      -- Filter out unlisted, scratch, nowrite buffers
      if buflisted and not disabled_buftypes[buftype] then
        local buf_name = vim.api.nvim_buf_get_name(buf_id)

        local display_name
        if buf_name == '' then
          display_name = '[No Name]'
        else
          -- Get just the filename, or full path if no filename (e.g., directories)
          display_name = vim.fn.fnamemodify(buf_name, ':t')
          if display_name == '' then
            display_name = buf_name -- Fallback to full path if it's a directory or complex path
          end
        end

        table.insert(cached_buffer_list, {
          buf_id = buf_id,
          name = display_name,
          is_current = (buf_id == current_buf_id),
        })
      end
    end
  end

  -- Create a map for MRU positions for quick lookup
  local mru_pos = {}
  for i, bufid in ipairs(mru_list) do
    mru_pos[bufid] = i
  end

  -- TODO: clear out MRU list if you can't find the buffer anymore

  -- Sort buffers by MRU order
  table.sort(cached_buffer_list, function(a, b)
    local pos_a = mru_pos[a.buf_id] or math.huge -- Assign high value if not in MRU (e.g., new buffer)
    local pos_b = mru_pos[b.buf_id] or math.huge

    if pos_a ~= pos_b then
      return pos_a < pos_b
    else
      -- Fallback to buffer ID if MRU positions are the same (or both not in MRU)
      return a.buf_id < b.buf_id
    end
  end)
end

local function get_content()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_line_idx = -1
  local content_lines = {}
  local max_content_width = 0

  for i, buf_info in ipairs(cached_buffer_list) do
    local prefix = buf_info.is_current and '' or ' '
    local line_text = string.format(' %s %s', prefix, buf_info.name)
    table.insert(content_lines, line_text)

    if buf_info.buf_id == current_buf then
      current_line_idx = i
    end

    max_content_width = math.max(max_content_width, vim.fn.strwidth(line_text))
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
  if vim.api.nvim_win_is_valid(floating_win_id) then
    vim.api.nvim_win_close(floating_win_id, true)
  end
  if vim.api.nvim_buf_is_valid(floating_buf_id) then
    -- Clear existing extmarks before deleting the old buffer
    vim.api.nvim_buf_clear_namespace(floating_buf_id, extmark_ns_id, 0, -1)
    vim.api.nvim_buf_delete(floating_buf_id, { force = true })
  end
end

local function ensure_window_visible()
  local content = get_content()

  -- Clear the autocmds that make the window invisible, so nothing can kill the window in
  -- the process of updating it
  local augroup = vim.api.nvim_create_augroup('RotorWindowClose', { clear = true })

  if not vim.api.nvim_buf_is_valid(floating_buf_id) then
    floating_buf_id = vim.api.nvim_create_buf(false, true)
  end

  local bufopts = vim.bo[floating_buf_id]

  -- Set buffer contents
  bufopts.modifiable = true
  vim.api.nvim_buf_set_lines(floating_buf_id, 0, -1, false, content.lines)

  -- Set buffer options
  bufopts.buftype = 'nofile'
  bufopts.bufhidden = 'wipe'
  bufopts.swapfile = false
  bufopts.modifiable = false

  -- Get window dimensions
  local win_width = vim.api.nvim_win_get_width(0)
  local win_height = vim.api.nvim_win_get_height(0)

  -- Calculate desired buffer dimensions and position
  local min_width = 20 -- Minimum width
  local max_display_width = 70 -- Max width of the floating window content
  local width = math.min(max_display_width, math.max(min_width, content.max_width + 2)) -- +2 for padding/border
  local height = math.min(win_height - 2, #content.lines + 2) -- +2 for padding/border

  -- Position at top-right
  local row = 0 -- math.floor((win_height - height) / 2)
  local col = win_width - 4 -- math.floor((win_width - width) / 2)

  -- Create the floating window configuration
  local win_config = {
    relative = 'win',
    row = row,
    col = col,
    width = width,
    height = height,
  }

  if vim.api.nvim_win_is_valid(floating_win_id) then
    vim.api.nvim_win_set_config(floating_win_id, win_config)
    vim.api.nvim_win_set_buf(floating_win_id, floating_buf_id)
  else
    -- Open the floating window without focusing it (second arg is false)
    floating_win_id = vim.api.nvim_open_win(
      floating_buf_id,
      false,
      vim.tbl_extend('error', {
        border = 'rounded', -- or 'rounded', 'double'
        title = 'Buffers',
        title_pos = 'center',
        anchor = 'NE', -- North-East anchor for top-right positioning
        style = 'minimal', -- Minimal styling
        focusable = false, -- Make it non-focusable so it doesn't steal focus
        noautocmd = true, -- Prevent autocommands from firing on window creation
      }, win_config)
    )
  end

  -- Set highlight for the border
  vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal,FloatBorder:FloatBorder', {
    scope = 'local',
    win = floating_win_id,
  })

  if content.highlight_line ~= 0 then
    -- Apply highlight to the current buffer's line using extmark
    vim.api.nvim_buf_set_extmark(floating_buf_id, extmark_ns_id, content.highlight_line - 1, 0, {
      hl_group = 'RotorSelectedLine',
      end_row = content.highlight_line,
      end_col = 0,
    })
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
        if not is_switching_now and is_switcher_active then
          -- Close the window
          close_window()

          -- Clear the autocommand group after closing
          vim.api.nvim_clear_autocmds { group = 'RotorWindowClose' }

          -- Reset the active flag and cached info when closing the window
          is_switcher_active = false
          cached_buffer_list = {}

          -- Update MRU list to have this buffer we've arrived at as the target
          update_mru_list()
        end
      end,
    })
  end, 50) -- A small delay (e.g., 50ms)
end

--- Opens the floating buffer with the buffer list content after switching buffers.
-- @param direction string: "next" or "prev" to indicate buffer switch direction.
function open_buffer_list_buffer(direction)
  -- If switcher isn't already active, write down the current MRU ordering of the buffers
  -- and mark as active
  if not is_switcher_active then
    is_switcher_active = true
    cache_buffer_list()
  end

  -- Find the index of the current buffer in our cached list
  local current_buf_id = vim.api.nvim_get_current_buf()
  local current_idx = -1
  for i, buf_info in ipairs(cached_buffer_list) do
    if buf_info.buf_id == current_buf_id then
      current_idx = i
      break
    end
  end

  -- Figure out what index should be next after this keypress
  local next_idx
  if current_idx == -1 then
    next_idx = 1
  elseif direction == 'next' then
    next_idx = (current_idx % #cached_buffer_list) + 1
  elseif direction == 'prev' then
    next_idx = math.max(current_idx - 1, 1)
  end
  local target_buf_id = cached_buffer_list[next_idx].buf_id

  -- Switch to the target buffer if it's different than the current one
  if target_buf_id ~= current_buf_id then
    is_switching_now = true
    vim.api.nvim_set_current_buf(target_buf_id)
    is_switching_now = false
  end

  -- Make sure the switcher window is visible
  ensure_window_visible()
end

function M.next()
  open_buffer_list_buffer 'next'
end

function M.prev()
  open_buffer_list_buffer 'prev'
end

return M
