local a = vim.api
local wo = vim.wo
local cmd = vim.cmd

local M = {}

local buf_valid = function () return M.buf and a.nvim_buf_is_valid(M.buf) end
local win_valid = function () return M.win and a.nvim_win_is_valid(M.win) end
local cnl_valid = function ()
  return M.chan and not vim.tbl_isempty(vim.tbl_filter(function(cnl)
    return cnl.id == M.chan
  end, a.nvim_list_chans()))
end

M.scroll = function(pos)
  if not pos then pos = {'$', 0} end
  local to_eob = function ()
    local line = vim.fn.line(pos[1])
    local col  = vim.fn.col(pos[2])
    a.nvim_win_set_cursor(M.win, {line,col})
  end
  if M.win ~= a.nvim_get_current_win() then
    a.nvim_win_call(M.win, to_eob)
  end
end

M.clear = function ()
  local prev_chan = M.chan
  M.chan = a.nvim_open_term(M.buf, {})
  vim.fn.chanclose(prev_chan)
end

M.print = function (input)
  if not cnl_valid() or not buf_valid() then M.validate()
  elseif not win_valid() then M.show() end
  if type(input) == "table" then input = vim.inspect(input) end
  if type(input) == "number" then input = tostring(input) end
  input = input:gsub("\n", "\r\n")
  vim.schedule(function()
    vim.schedule(function()
      a.nvim_chan_send(M.chan, input .. '\r\n')
      M.scroll()
    end)
  end)
end

M.liveprint = function (input)
  M.print(input)
end

M.runfile = function ()
  if M.exists() then M.clear() end
  local cursorpos = vim.api.nvim_win_get_cursor(0)
  local oldprint = print
  print = M.liveprint
  cmd('luafile %')
  print = oldprint
  vim.api.nvim_win_set_cursor(0, cursorpos)
end

M.validate = function()
  if not M.initialized then M.init() return else M.new() return end
end

M.exists = function ()
  return win_valid() and buf_valid() and cnl_valid()
end

M.show = function ()
  M.create_win()
  a.nvim_win_set_buf(M.win, M.buf)
end

M.close = function ()
  a.nvim_win_close(M.win, true)
end

M.create_win = function ()
  local oldwin = a.nvim_get_current_win() --record current window
  cmd("vsplit")
  M.win = a.nvim_get_current_win()
  wo.number = false
  wo.relativenumber = false
  wo.numberwidth = 1
  wo.signcolumn = "no"
  a.nvim_set_current_win(oldwin)
end

M.create_term = function ()
  M.buf = not buf_valid() and a.nvim_create_buf(false, true) or M.buf
  M.chan = a.nvim_open_term(M.buf, {})
  return M.buf
end

M.new = function ()
  M.create_win()
  M.create_term()
  a.nvim_win_set_buf(M.win, M.buf)
end

M.init = function ()
  M.initialized = true
  local linked_win = a.nvim_get_current_win()
  M.print_buf =  M.exists() or M.new()
  a.nvim_create_autocmd({"WinClosed"},{
    callback = vim.schedule_wrap(function ()
      if not a.nvim_win_is_valid(linked_win) then
        local valid, _ = pcall(function() a.nvim_win_close(M.win, true) end)
        if not valid then cmd('quit') end
      end
    end),
    once = false
  })
  return M
end

return M
