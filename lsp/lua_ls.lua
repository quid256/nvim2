return {
  settings = {
    Lua = {
      completion = { callSnippet = 'Replace' },
      diagnostics = { disable = { 'missing-fields' } },
      hint = { -- Enable inlay hints
        enable = true,
        arrayIndex = 'Disable',
      },
    },
  },
}
