local ls = require 'luasnip'
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
-- local f = ls.function_node
local d = ls.dynamic_node
local c = ls.choice_node
local sn = ls.snippet_node
local k = require('luasnip.nodes.key_indexer').new_key
local isn = ls.indent_snippet_node
local fmt = require('luasnip.extras.fmt').fmt
local types = require 'luasnip.util.types'

local function node_with_virtual_text(pos, node, text)
  local nodes
  if node.type == types.textNode then
    node.pos = 2
    nodes = { i(1), node }
  else
    node.pos = 1
    nodes = { node }
  end
  return sn(pos, nodes, {
    node_ext_opts = {
      active = {
        virt_text = { { text, 'LspInlayHint' } },
      },
    },
  })
end

local function nodes_with_virtual_text(nodes, opts)
  if opts == nil then
    opts = {}
  end
  local new_nodes = {}
  for pos, node in ipairs(nodes) do
    if opts.texts[pos] ~= nil then
      node = node_with_virtual_text(pos, node, opts.texts[pos])
    end
    table.insert(new_nodes, node)
  end
  return new_nodes
end

local function choice_text_node(pos, choices, opts)
  choices = nodes_with_virtual_text(choices, opts)
  return c(pos, choices, opts)
end

local ct = choice_text_node

ls.add_snippets('python', {
  s(
    'at',
    fmt([[{}: {} = attr.ib({})]], {
      i(1, 'field_name'),
      i(2, '...'),
      i(3, ''),
    })
  ),
  s(
    'atk',
    fmt([[{}: {} = attr.ib(kw_only=True, default={})]], {
      i(1, 'field_name'),
      i(2, '...'),
      i(3, '...'),
    })
  ),
  -- [D]efine [F]unction, automatically adds template docstring
  s(
    'df',
    fmt(
      [[
      def {func}({args}){ret}:
          {doc}{body}
    ]],
      {
        func = i(1),
        args = i(2, nil, { key = 'args_node' }),
        ret = c(3, {
          t '',
          sn(nil, {
            t ' -> ',
            i(1),
          }),
        }),
        doc = isn(4, {
          ct(1, {
            sn(
              1,
              fmt(
                [[
                """
                {desc}

                {args}:return: {returns}
                """

                ]],
                {
                  desc = i(1),
                  args = d(2, function(text)
                    -- Now, func_args_text_from_root contains the text from the top-level i(2) node
                    local func_args_str =
                      string.gsub(table.concat(text[1], ''), '^%s*(.-)%s*$', '%1') -- Trim whitespace

                    if func_args_str == '' then
                      return sn(1, { t '' })
                    end

                    local patterns = {
                      '%s*([%w_]+)%s*:[^,%[]*%b[],?',
                      '%s*([%w_]+)%s*:[^,%[]*,?',
                      '%s*([%w_]+)%s*,?',
                    }

                    local arg_names = {}

                    local ind = 1
                    local j = 1
                    print('func_args_str = ', vim.inspect(func_args_str))
                    while ind <= #func_args_str do
                      local found_thing = false
                      for _, pat in ipairs(patterns) do
                        local starti, endi, capture = string.find(func_args_str, pat, ind)
                        print('pat = ', vim.inspect(pat))
                        print('capture = ', vim.inspect(capture))
                        if starti == ind and endi ~= nil and capture ~= nil then
                          vim.list_extend(
                            arg_names,
                            fmt(
                              [[
                              :param {capture}: {description}
                              
                              ]],
                              { capture = t(capture), description = i(j) }
                            )
                          )
                          j = j + 1
                          ind = endi + 1
                          found_thing = true
                          break
                        end
                      end

                      if not found_thing then
                        print 'not found thing'
                        return sn(1, {
                          t {
                            "(Can't parse arg list)",
                            '',
                          },
                        })
                      end
                    end
                    return sn(1, arg_names)
                  end, k 'args_node'), -- TODO should read from the args in the function
                  returns = i(3),
                }
              )
            ),
            sn(
              2,
              fmt(
                [[
                """{desc}"""

                ]],
                { desc = i(1) }
              )
            ),
            t '',
          }, {
            texts = {
              '(full docstring)',
              '(single line docstring)',
              '(no docstring)',
            },
          }),
        }, '$PARENT_INDENT\t'),
        body = i(0),
      }
    )
  ),
}, { key = 'python' })
