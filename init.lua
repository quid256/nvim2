local util = require 'util'

-- Settings
util.batch_update(vim.g, {
  -- <leader> and <localleader> to ' ' and ','
  mapleader = ' ',
  maplocalleader = ',',

  -- user-defined config to fork on whether a nerd font is present
  have_nerd_font = true,
})

util.batch_update(vim.opt, {
  -- Text editing defaults
  number = true,
  relativenumber = true,
  signcolumn = 'yes',
  spell = false,
  colorcolumn = '90',
  textwidth = 90,
  wrap = false,
  shiftwidth = 4,
  tabstop = 4,
  breakindent = true, -- Enable break indent
  expandtab = true,
  mouse = 'a', -- Enable mouse mode, can be useful for resizing splits for example!

  -- Don't show the mode, since it's already in the status line
  showmode = false,
  undofile = true, -- Save undo history

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  ignorecase = true,
  smartcase = true,

  -- time lengths for key chords
  updatetime = 250,
  timeoutlen = 300,

  -- Configure how new splits should be opened
  splitright = true,
  splitbelow = true,

  -- Sets how neovim will display certain whitespace characters in the editor.,
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  list = true,
  listchars = { tab = '» ', trail = '·', nbsp = '␣' },

  -- Don't do the weird ~'s at the end of the buffer
  fillchars = { eob = ' ' },

  -- Preview substitutions live, as you type!
  inccommand = 'split',

  -- Show which line your cursor is on
  cursorline = true,

  -- Minimal number of screen lines to keep above and below the cursor.
  scrolloff = 10,

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  -- See `:help 'confirm'`
  confirm = true,
})

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

--

-- Keymaps
util.foreach(vim.keymap.set, {
  -- { 'i', 'fd', '<Esc>', { desc = 'Exit insert mode' } },
  -- { 't', 'fd', '<C-\\n><C-n>', { desc = 'Exit terminal mode' } },
  { 't', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' } },

  -- Use M-{j,k} to navigate quickfix list
  { { 'n', 'i' }, '<M-j>', '<cmd>cnext<cr>', { desc = 'QF Next' } },
  { { 'n', 'i' }, '<M-k>', '<cmd>cprev<cr>', { desc = 'QF Prev' } },
  { { 'n', 'i' }, '<M-S-j>', '<cmd>lnext<cr>', { desc = 'Loclist Next' } },
  { { 'n', 'i' }, '<M-S-k>', '<cmd>lprev<cr>', { desc = 'Loclist Prev' } },

  -- Use M-{j,k} to navigate quickfix list
  { 'n', '<M-o>', '<cmd>wincmd o<cr>', { desc = 'Make this the only window' } },

  -- Diagnostic QF list
  { 'n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' } },

  -- Easier window navigation
  { 'n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' } },
  { 'n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' } },
  { 'n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' } },
  { 'n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' } },
  { -- Terminal goer
    { 'n', 't' },
    '<C-t>',
    function()
      local function is_buf_terminal(bufnr)
        return vim.bo[bufnr].buftype == 'terminal'
      end

      if is_buf_terminal(vim.api.nvim_get_current_buf()) then
        vim.cmd [[ b # ]]
        return
      end

      local to_buf = -1
      for _, nr in ipairs(vim.api.nvim_list_bufs()) do
        if is_buf_terminal(nr) then
          to_buf = nr
          break
        end
      end

      if to_buf > -1 then
        vim.api.nvim_set_current_buf(to_buf)
      else
        vim.cmd [[ term ]]
      end
      vim.cmd [[ startinsert ]]
    end,
    { desc = 'Go to primary terminal' },
  },
})

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Plugins
util.ensure_lazy_installed()
require('lazy').setup({
  {
    'yorickpeterse/nvim-pqf',
    event = 'UIEnter',
    opts = {},
  },

  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    opts = {
      graph_style = 'unicode',
      kind = 'floating',
      commit_editor = {
        kind = 'floating',
      },
      mappings = {
        status = {
          ['h'] = 'Toggle',
        },
      },
      signs = {
        item = { '󰅂', '󰅀' },
        section = { '󰅂', '󰅀' },
      },
    },
    keys = {
      {
        '<localleader>g',
        function()
          require('neogit').open()
        end,
        desc = 'Open Neo[g]it',
      },
    },
  },

  'gpanders/editorconfig.nvim',
  { -- automatically turn off hlsearch
    'nvimdev/hlsearch.nvim',
    name = 'hlsearch',
    event = 'BufRead',
    opts = {},
  },
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  -- Use ; as : for entering commands
  { 'edte/normal-colon.nvim', opts = {} },

  { -- zen-mode
    'folke/zen-mode.nvim',
    opts = {},
    keys = {
      {
        '<leader>z',
        function()
          require('zen-mode').toggle()
        end,
        desc = 'Toggle [Z]en Mode',
      },
    },
  },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      preset = 'helix',
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.opt.timeoutlen
      delay = 200,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>t', group = '[T]oggle' },
      },
    },
  },

  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    event = 'VeryLazy',
    opts = {
      prompt_func_return_type = {
        go = false,
        java = false,
        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      prompt_func_param_type = {
        go = false,
        java = false,
        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      printf_statements = {},
      print_var_statements = {},
      show_success_message = true, -- shows a message with information about the refactor on success
    },
    config = function(_, opts)
      local refactoring = require 'refactoring'

      refactoring.setup(opts)
      util.foreach(vim.keymap.set, {
        {
          { 'n', 'x' },
          '<leader>ri',
          function()
            return refactoring.refactor 'Inline Variable'
          end,
          { expr = true, desc = 'Inline Variable' },
        },
        {
          { 'n', 'x' },
          '<leader>rb',
          function()
            return refactoring.refactor 'Extract Block'
          end,
          { expr = true, desc = 'Extract Block' },
        },
        {
          { 'n', 'x' },
          '<leader>rf',
          function()
            return refactoring.refactor 'Extract Block To File'
          end,
          { expr = true, desc = 'Extract Block To File' },
        },
        {
          { 'n', 'x' },
          '<leader>rP',
          function()
            return refactoring.debug.printf { below = false }
          end,
          { expr = true, desc = 'Debug Print' },
        },
        {
          { 'n', 'x' },
          '<leader>rp',
          function()
            return refactoring.debug.print_var { normal = true }
          end,
          { expr = true, desc = 'Debug Print Variable' },
        },
        {
          { 'n', 'x' },
          '<leader>rc',
          function()
            return refactoring.debug.cleanup {}
          end,
          { expr = true, desc = 'Debug Cleanup' },
        },
        {
          { 'n', 'x' },
          '<leader>rf',
          function()
            return refactoring.refactor 'Extract Function'
          end,
          { expr = true, desc = 'Extract Function' },
        },
        {
          { 'n', 'x' },
          '<leader>rF',
          function()
            return refactoring.refactor 'Extract Function To File'
          end,
          { expr = true, desc = 'Extract Function To File' },
        },
        {
          { 'n', 'x' },
          '<leader>rx',
          function()
            return refactoring.refactor 'Extract Variable'
          end,
          { expr = true, desc = 'Extract Variable' },
        },
      })
    end,
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
      'rktjmp/lush.nvim',
    },
    config = function()
      local telescope = require 'telescope'
      local actions = require 'telescope.actions'

      telescope.setup {
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
        defaults = {
          borderchars = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
          mappings = {
            n = { ['<c-d>'] = actions.delete_buffer },
            i = { ['<c-d>'] = actions.delete_buffer },
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(telescope.load_extension, 'fzf')
      pcall(telescope.load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      util.foreach(vim.keymap.set, {
        { 'n', '<leader>h', builtin.help_tags, { desc = 'Search [H]elp' } },
        { 'n', '<leader>k', builtin.keymaps, { desc = 'Search [K]eymaps' } },
        { 'n', '<leader>f', builtin.find_files, { desc = 'Search [F]iles' } },
        { 'n', '<leader>T', builtin.builtin, { desc = 'Search [T]elescopes' } },
        { 'n', '<leader>W', builtin.grep_string, { desc = 'Search current [W]ord' } },
        { 'n', '<leader>g', builtin.live_grep, { desc = 'Search by [G]rep' } },
        { 'n', '<leader>d', builtin.diagnostics, { desc = 'Search [D]iagnostics' } },
        -- { 'n', '<leader>r', builtin.resume, { desc = 'Search [R]esume' } },
        { 'n', '<leader>.', builtin.oldfiles, { desc = 'Search Recent Files ("." for repeat)' } },
        { 'n', '<leader>j', builtin.buffers, { desc = 'Search Buffers' } },
        {
          'n',
          '<leader>/',
          function()
            builtin.current_buffer_fuzzy_find(
              require('telescope.themes').get_dropdown { winblend = 10, previewer = false }
            )
          end,
          { desc = '[/] Fuzzily search in current buffer' },
        },
        {
          'n',
          '<leader>c',
          function()
            builtin.find_files { cwd = vim.fn.stdpath 'config' }
          end,
          { desc = 'Search Neovim [C]onfig' },
        },
        {
          'n',
          '<leader>C',
          function()
            builtin.colorscheme {
              enable_preview = true,
              ignore_builtins = true,
              winblend = 10,
              layout_config = {
                height = 0.3,
              },
            }
          end,
          { desc = 'Search [C]olor schemes' },
        },
      })

      -- Fancy logic to manually update telescope themeing
      local function update_colors()
        local lush = require 'lush'
        local hsl = lush.hsl

        local function get_hl(name, key)
          local hl_col = vim.api.nvim_get_hl(0, { name = name, link = false })
          if hl_col == nil then
            error('hl_col is nil for ' .. name)
          end
          local col_num = hl_col[key] or hl_col['gui' .. key]
          if col_num == nil then
            print(vim.inspect(hl_col) .. ' (' .. name .. ") doesn't have " .. key)
            return nil
          end

          return hsl(string.format('#%06x', col_num))
        end

        local colors = {
          string_fg = get_hl('@string', 'fg'),
          conditional_fg = get_hl('@conditional', 'fg'),
          normal_bg = get_hl('Normal', 'bg'),
        }

        colors.prompt_bg = colors.normal_bg.lighten(5)
        colors.main_bg = colors.normal_bg.darken(12)
        colors.darker_bg = colors.normal_bg.darken(19)

        local spec = lush(function()
          return {
            ---@diagnostic disable
            TelescopeTitle { fg = colors.normal_bg, bg = colors.conditional_fg },
            TelescopeNormal { bg = colors.main_bg },
            TelescopeBorder { bg = colors.main_bg },

            -- TelescopePromptTitle { fg = colors.normal_bg, bg = colors.conditional_fg },
            -- TelescopePreviewTitle { fg = colors.normal_bg, bg = colors.conditional_fg },
            -- TelescopeResultsTitle { fg = colors.normal_bg, bg = colors.conditional_fg },
            TelescopePromptNormal { bg = colors.prompt_bg },
            TelescopePromptBorder { bg = colors.prompt_bg },
            TelescopeSelection { bg = colors.prompt_bg },
            TelescopeResultsNormal { bg = colors.main_bg },
            TelescopeResultsBorder { bg = colors.main_bg },
            TelescopePreviewNormal { bg = colors.darker_bg },
            TelescopePreviewBorder { bg = colors.darker_bg },
            ---@diagnostic enable
          }
        end)
        lush(spec, { force_clean = false })
      end

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('custom-colorscheme', { clear = true }),
        callback = update_colors,
      })

      update_colors()
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      { 'williamboman/mason.nvim', opts = {} },
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          util.foreach(map, {
            { 'gr', vim.lsp.buf.rename, 'ename' },
            { 'gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition' },
            { 'ga', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' } },
            { 'gR', require('telescope.builtin').lsp_references, '[G]oto [R]eferences' },
            { 'gi', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation' },
            { 'gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration' },
            { 'gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols' },
            {
              'gW',
              require('telescope.builtin').lsp_dynamic_workspace_symbols,
              'Open Workspace Symbols',
            },
            { 'gT', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition' },
          })

          -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              -- this is for backwards-compat, so disable
              ---@diagnostic disable-next-line
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if
            client
            and client_supports_method(
              client,
              vim.lsp.protocol.Methods.textDocument_documentHighlight,
              event.buf
            )
          then
            local highlight_augroup =
              vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if
            client
            and client_supports_method(
              client,
              vim.lsp.protocol.Methods.textDocument_inlayHint,
              event.buf
            )
          then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Modify to add new servers
      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
              diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
        zls = {},
        ts_ls = {},
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
        automatic_installation = false,
        automatic_enable = true,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities =
              vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<localleader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        rust = {},
        zig = {},
        -- python = { "isort", "black" },
        javascript = { 'prettierd', stop_after_first = true },
        typescript = { 'prettierd', stop_after_first = true },
        jsx = { 'prettierd', stop_after_first = true },
        html = { 'prettierd', stop_after_first = true },
        css = { 'prettierd', stop_after_first = true },
      },
    },
  },

  { -- Snippets
    'L3MON4D3/LuaSnip',
    version = '2.*',
    build = (function()
      if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
        return
      end
      return 'make install_jsregexp'
    end)(),
    dependencies = {
      {
        'rafamadriz/friendly-snippets',
        config = function()
          require('luasnip.loaders.from_vscode').lazy_load()
        end,
      },
    },
    opts = {},
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      'L3MON4D3/LuaSnip',
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        preset = 'super-tab',
      },
      appearance = {
        nerd_font_variant = 'mono',
      },
      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },
      snippets = { preset = 'luasnip' },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
      signature = { enabled = true },
    },
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - maiw) - [M]atch [A]dd [I]nner [W]ord [)]Paren
      -- - md'   - [M]atch [D]elete [']quotes
      -- - mr)'  - [M]atch [R]eplace [)] [']
      require('mini.surround').setup {
        mappings = {
          add = 'ma', -- Add surrounding in Normal and Visual modes
          delete = 'md', -- Delete surrounding
          find = 'mf', -- Find surrounding (to the right)
          find_left = 'mF', -- Find surrounding (to the left)
          highlight = 'mh', -- Highlight surrounding
          replace = 'mr', -- Replace surrounding
          update_n_lines = 'mn', -- Update `n_lines`

          suffix_last = 'l', -- Suffix to search with "prev" method
          suffix_next = 'n', -- Suffix to search with "next" method
        },
        n_lines = 1000,
      }

      -- Make terminal background color same as nvim bg color
      require('mini.misc').setup_termbg_sync()

      -- pretty notifications in top left
      require('mini.notify').setup {
        lsp_progress = {
          enable = false,
        },
      }

      require('mini.starter').setup {}
    end,
  },

  {
    'nvim-lualine/lualine.nvim',
    opts = {
      icons_enabled = vim.g.have_nerd_font,

      options = {
        component_separators = '',
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = {
          {
            'mode',
            fmt = function(res)
              return res:sub(1, 1)
            end,
          },
        },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
    },
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'python',
        'rust',
        'zig',
        'javascript',
        'typescript',
      },

      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = (function()
            local result = {}
            for _, region in ipairs { 'a', 'i' } do
              for char, obj in pairs {
                f = 'function',
                c = 'class',
                l = 'call',
                k = 'conditional',
                m = 'comment',
              } do
                result[region .. char] = ('@%s.%s'):format(
                  obj,
                  (region == 'a' and 'outer' or 'inner')
                )
              end
            end
            return result
          end)(),
          selection_modes = {},
          include_surrounding_whitespace = true,
        },
      },
    },
  },
  {
    'ggandor/leap.nvim',
    dependencies = { 'tpope/vim-repeat' },
    config = function()
      local leap = require 'leap'
      leap.set_default_mappings()
      leap.opts.preview_filter = function(ch0, ch1, ch2)
        return not (ch1:match '%s' or ch0:match '%a' and ch1:match '%a' and ch2:match '%a')
      end
      leap.opts.safe_labels = {}
      vim.api.nvim_set_hl(0, 'LeapBackdrop', { link = 'Comment' })
    end,
  },

  {
    { -- Add indentation guides even on blank lines
      'lukas-reineke/indent-blankline.nvim',
      main = 'ibl',
      opts = {
        scope = {
          enabled = true,
          show_start = false,
          show_end = false,
        },
      },
    },
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },

  { -- Git signs
    'lewis6991/gitsigns.nvim',
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        util.foreach(function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end, {
          {
            'n',
            ']c',
            function()
              if vim.wo.diff then
                vim.cmd.normal { ']c', bang = true }
              else
                gitsigns.nav_hunk 'next'
              end
            end,
            { desc = 'Jump to next git [c]hange' },
          },
          {
            'n',
            '[c',
            function()
              if vim.wo.diff then
                vim.cmd.normal { '[c', bang = true }
              else
                gitsigns.nav_hunk 'prev'
              end
            end,
            { desc = 'Jump to previous git [c]hange' },
          },

          -- Actions
          -- visual mode
          -- {
          --   'v',
          --   '<leader>hs',
          --   function()
          --     gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
          --   end,
          --   { desc = 'git [s]tage hunk' },
          -- },
          -- {
          --   'v',
          --   '<leader>hr',
          --   function()
          --     gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
          --   end,
          --   { desc = 'git [r]eset hunk' },
          -- },
          -- -- normal mode
          -- { 'n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' } },
          -- { 'n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' } },
          -- { 'n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' } },
          -- { 'n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' } },
          -- { 'n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' } },
          -- { 'n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' } },
          -- { 'n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' } },
          -- { 'n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' } },
          -- {
          --   'n',
          --   '<leader>hD',
          --   function()
          --     gitsigns.diffthis '@'
          --   end,
          --   { desc = 'git [D]iff against last commit' },
          -- },
          -- -- Toggles
          -- {
          --   'n',
          --   '<leader>tb',
          --   gitsigns.toggle_current_line_blame,
          --   { desc = '[T]oggle git show [b]lame line' },
          -- },
          -- {
          --   'n',
          --   '<leader>tD',
          --   gitsigns.preview_hunk_inline,
          --   { desc = '[T]oggle git show [D]eleted' },
          -- },
        })
      end,
    },
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
      { ' n', ':Neotree toggle<CR>', desc = 'NeoTree reveal', silent = true },
    },
    opts = {
      filesystem = {
        window = {
          mappings = {
            [' n'] = 'close_window',
          },
        },
      },
    },
  },

  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'catppuccin-frappe'
    end,
  },
  { 'rose-pine/neovim', name = 'rose-pine' },
  {
    dir = vim.fn.stdpath 'config' .. '/lua/plugins/rotor',
    keys = {
      {
        '<M-n>',
        function()
          require('plugins.rotor').next()
        end,
      },
      {
        '<M-p>',
        function()
          require('plugins.rotor').prev()
        end,
      },
    },
  },
  {
    dir = vim.fn.stdpath 'config' .. '/lua/plugins/floating_buffers',
    keys = {
      {
        '<localleader>l',
        function()
          require('plugins.floating_buffers').FloatingBuffers:toggle 'terminal'
        end,
        desc = 'Toggle F[l]oating Terminal',
      },
    },
    config = function()
      local fb = require 'plugins.floating_buffers'
      fb.FloatingBuffers:setup(
        'terminal',
        { terminal_buffer = true, win_config = { title = 'Terminal' } }
      )
    end,
  },
}, { ---@diagnostic disable-line
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
-- vim: ts=2 sts=2 sw=2 et
