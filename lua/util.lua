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
