local M = {}

local MODULE_CACHE = {}

function M.setup()
  vim.api.nvim_create_autocmd({ 'FileType' }, {
    callback = function(ev)
      if MODULE_CACHE[ev.match] == nil then
        local status, err_or_result = pcall(require, 'plugins.ftonce.' .. ev.match)
        if status then
          MODULE_CACHE[ev.match] = err_or_result
        end
      end
    end,
  })
end

return M
