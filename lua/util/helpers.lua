local M = {}

function M.batch_update(tbl, update)
  for k, v in pairs(update) do
    tbl[k] = v
  end
end

function M.foreach(fn, tables)
  for _, v in ipairs(tables) do
    fn(unpack(v))
  end
end

return M
