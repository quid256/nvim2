local ls = require 'luasnip'
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local fmt = require('luasnip.extras.fmt').fmt
local types = require 'luasnip.util.types'

ls.add_snippets('lua', {
  s(
    'dbp',
    fmt( --
      'print("{dup} = ", vim.inspect({qty}))',
      {
        dup = f(function(res)
          return res[1][1]
        end, { 1 }),
        qty = i(1),
      }
    )
  ),
})
