return vim.tbl_extend(
  'error', -- raies if there are duplicate names returned
  require 'util.helpers', -- various basic helpers
  require 'util.packages' -- utilities for package management
)
