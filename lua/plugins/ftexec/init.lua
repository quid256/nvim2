local M = {}

local loaded_packages = {}

function M.setup()
  vim.api.nvim_create_autocmd({ 'FileType' }, {
    callback = function(ev)
      local package_name = 'plugins.ftexec.' .. ev.match
      local status, mod = pcall(require, package_name)
      if status then
        loaded_packages[package_name] = true
        mod.run()
      end
    end,
  })
end

function M.reset()
  for pkg_name, _ in pairs(loaded_packages) do
    local pkg = package.loaded[pkg_name]
    if pkg.reset ~= nil then
      pkg.reset()
    end
    package.loaded[pkg_name] = nil
  end
  loaded_packages = {}
  print 'ftexecs reset'
end

return M
