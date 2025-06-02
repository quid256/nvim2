local M = {}

---Execute fn for each entry in tables
---@param tbl table
---@param update table
function M.batch_update(tbl, update)
  for k, v in pairs(update) do
    tbl[k] = v
  end
end

---Execute fn for each entry in tables
---@param fn fun(...): nil
---@param tables table[]
function M.foreach(fn, tables)
  for _, v in ipairs(tables) do
    fn(unpack(v))
  end
end

---Lazily load a module's function specified as module:function, and apply it after some
---default arguments
---@param spec string
---@return function
function M.partial(spec, ...)
  local module_name, field = unpack(vim.split(spec, ':'))
  local always_arg = ...

  local function wrapped(...)
    return require(module_name)[field](always_arg, ...)
  end

  return wrapped
end

--- Promisifies a callback-based async function to work with coroutines.
--- Assumes the callback's first argument is an error (or nil) and subsequent arguments are results.
--- @param fn_taking_callback function Calls a callback as its last argument
--- @return function A new function that can be called within a coroutine and will yield.
local function await(fn_taking_callback)
  return function(...)
    local args = { ... }
    local current_co = coroutine.running()
    assert(current_co, 'await() must be called from within a coroutine')

    -- The actual callback that will resume the coroutine
    local function cb(err, ...)
      if not coroutine.resume(current_co, err, ...) then
        vim.notify(
          'Coroutine resume failed for: ' .. tostring(fn_taking_callback),
          vim.log.levels.ERROR
        )
      end
    end

    fn_taking_callback(unpack(args), cb)
    return coroutine.yield()
  end
end

---@generic T
---@param fn function(): T
---@param ms integer
---@param default T
---@return function(): T
function M.ttl_cache(fn, ms, default)
  local output = default
  local stale = true
  local timer = vim.uv.new_timer()
  local co
  if timer == nil then
    error "Couldn't create timer for ttl_cache"
  end

  local function get()
    if stale then
      stale = false
      co = coroutine.create(function()
        -- Call the function (can be async)
        output = fn()

        -- Wait for the timer to finish
        timer:start(ms, 0, function()
          assert(coroutine.resume(co), 'Failed to resume')
        end)
        coroutine.yield()

        -- Mark the result as stale
        stale = true
      end)
      coroutine.resume(co)
    end
    return output
  end

  return get
end

---Ensure that lazy.nvim is installed
function M.ensure_lazy_installed()
  local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out =
      vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
    if vim.v.shell_error ~= 0 then
      error('Error cloning lazy.nvim:\n' .. out)
    end
  end ---@diagnostic disable-next-line: undefined-field
  vim.opt.rtp:prepend(lazypath)
end

return M
