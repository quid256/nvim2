local M = {}

---@return string
local function ensure_nvr_installed()
  local function mkdir(path)
    if vim.fn.empty(vim.fn.glob(path)) > 0 then
      print('[NVR] Creating ' .. path)
      vim.fn.mkdir(path, 'p')
      return true
    end
    return false
  end

  local pkg_dir = vim.fn.stdpath 'data' .. '/neovim-remote'
  mkdir(pkg_dir)

  local venv_dir = pkg_dir .. '/venv'
  local bin_path = pkg_dir .. '/bin'

  if mkdir(venv_dir) then
    -- Set up the venv
    print '[NVR] Creating VENV'
    vim.system({ 'python3', '-m', 'venv', venv_dir }):wait()
    vim.system { venv_dir .. '/bin/python3', '-m', 'pip', 'install', '--upgrade', 'pip' }
    vim.system { venv_dir .. '/bin/python3', '-m', 'pip', 'install', 'neovim-remote' }

    -- Set up the bin directory, symlink over just NVR
    print '[NVR] SymLinking'
    mkdir(bin_path)
    vim.system { 'ln', '-s', venv_dir .. '/bin/nvr', bin_path .. '/nvr' }
    print '[NVR] Done!'
  end

  return bin_path
end

function M.setup(opts)
  local bin_path = ensure_nvr_installed()

  -- Set up environment variables so venv works
  vim.fn.setenv('PATH', bin_path .. ':' .. vim.fn.getenv 'PATH')
  vim.fn.setenv('EDITOR', 'nvr -cc split --remote-wait')
  vim.fn.setenv('GIT_EDITOR', 'nvr -cc split --remote-wait')

  vim.api.nvim_create_user_command('NVRUpdate', function()
    -- Entirely delete the neovim-remote path
    print '[NVR] Deleting existing setup'
    vim.system { 'rm', '-rf', vim.fn.stdpath 'data' .. '/neovim-remote' }

    -- Reinstall everything
    ensure_nvr_installed()
  end, {})
end
return M
