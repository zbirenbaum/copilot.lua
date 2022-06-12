local a = vim.api
local cmd = vim.cmd
local wo = vim.wo

local print_buf = {}

print_buf.set_text = function (full_text)
  local ft = vim.bo.filetype
  vim.api.nvim_buf_call(print_buf.bufnr, function ()
    vim.bo.filetype = ft
  end)
  vim.api.nvim_buf_set_lines(print_buf.bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_var(print_buf.bufnr, "modifiable", 1)
  vim.api.nvim_buf_set_var(print_buf.bufnr, "readonly", 0)
  vim.api.nvim_buf_set_lines(print_buf.bufnr, 0, #full_text, false,full_text)
end

local create_win = function ()
  local oldwin = a.nvim_get_current_win() --record current window
  cmd("vsplit")
  local win = a.nvim_get_current_win()
  wo.number = false
  wo.relativenumber = false
  wo.numberwidth = 1
  wo.signcolumn = "no"
  a.nvim_set_current_win(oldwin)
  return win
end

print_buf.create = function (bufnr)
  print_buf.bufnr = bufnr
  print_buf.win = create_win()
  a.nvim_win_set_buf(print_buf.win, print_buf.bufnr)
end

return print_buf
