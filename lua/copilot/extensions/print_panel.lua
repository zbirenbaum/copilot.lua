local a = vim.api
local cmd = vim.cmd
local wo = vim.wo
local handler = require("copilot.handlers")
local format = require("copilot_cmp.format")
local print_panel = {}

local set_text = function (full_text)
  a.nvim_buf_set_option(print_panel.bufnr, "modifiable", true)
  a.nvim_buf_set_option(print_panel.bufnr, "readonly", false)
  a.nvim_buf_set_lines(print_panel.bufnr, 0, -1, false, {})
  local ft = vim.bo.filetype
  a.nvim_buf_call(print_panel.bufnr, function ()
    vim.bo.filetype = ft
  end)
  a.nvim_buf_set_lines(print_panel.bufnr, 0, #full_text, false,full_text)
  vim.schedule(function()
    a.nvim_buf_set_option(print_panel.bufnr, "modifiable", false)
    a.nvim_buf_set_option(print_panel.bufnr, "readonly", true)
  end)
end

local format_entry = function (number, str)
  local lines = {}
  for s in str:gmatch("[^\r\n]+") do table.insert(lines, s) end
  table.insert(lines, '')
  return {
    len = #lines,
    lines = lines,
    number = number,
  }
end

local sort_items = function (items)
  local sorted = {}
  for fmt_string, value in pairs(items) do
    sorted[value.score] = fmt_string
  end
  return sorted
end

local make_entries = function (items)
  local entries = {}
  items = sort_items(items)
  for number, str in ipairs(vim.tbl_values(items)) do
    table.insert(entries, format_entry(number, str))
  end
  for index, _ in ipairs(entries) do
    local last = entries[index-1]
    entries[index].linenr = last and last.linenr + last.len or 1
  end
  return entries
end

local get_full_text = function (entries)
  return vim.tbl_flatten(vim.tbl_map(function(e)
    return e.lines
  end, entries))
end

print_panel.add_panel_callbacks = function ()
  local items = {}

  handler.add_handler_callback("PanelSolution", "pb", function (result)
    local formatted = format.deindent(result.displayText)
    items[formatted] = result
  end)

  handler.add_handler_callback("PanelSolutionsDone", "pb", function ()
    if vim.tbl_isempty(items) then return end
    print_panel.entries = make_entries(items)
    print_panel.current = 1
    set_text(get_full_text(print_panel.entries))
    items = {}
  end)
end

local create_win = function ()
  local oldwin = a.nvim_get_current_win() --record current window
  local height = tostring(math.floor(a.nvim_win_get_height(oldwin)*.3))
  cmd(height .. "split")
  local win = a.nvim_get_current_win()
  wo.number = false
  wo.relativenumber = false
  wo.numberwidth = 1
  wo.signcolumn = "no"
  a.nvim_set_current_win(oldwin)
  return win
end

print_panel.insert = function ()
  print(vim.inspect(print_panel.entries))
end
print_panel.select = function (id)
  if not id then id = print_panel.current or 1 end
  local selection = print_panel.entries[id]
  a.nvim_win_set_cursor(print_panel.win, {selection.linenr, 0})
  cmd("normal zt")
  print_panel.current = id
  print_panel.linenr = selection.linenr
end

print_panel.next = function ()
  local entries = print_panel.entries
  local current = print_panel.current
  local id = entries[current+1] and current+1 or 1
  print_panel.select(id)
end

print_panel.prev = function ()
  local entries = print_panel.entries
  local current = print_panel.current
  local id = entries[current-1] and current-1 or #entries
  print_panel.select(id)
end

print_panel.set_options = function ()
  local opts = {
    win = { fcs = "eob: ", signcolumn = "no", list = false},
    buf = { bufhidden = "wipe", buftype = "nofile", swapfile = false, buflisted = false, }
  }
  for option, value in pairs(opts.win) do
    a.nvim_win_set_option(print_panel.win, option, value)
  end

  for option, value in pairs(opts.buf) do
    a.nvim_buf_set_option(print_panel.bufnr, option, value)
  end
end

print_panel.create = function (bufnr)
  print_panel.bufnr = bufnr
  print_panel.win = create_win()
  print_panel.last = 1
  a.nvim_win_set_buf(print_panel.win, print_panel.bufnr)
  print_panel.set_options()
  print_panel.add_panel_callbacks()

  local keymaps = {
    ["j"] = print_panel.next,
    ["k"] = print_panel.prev,
    ["<CR>"] = print_panel.insert,
  }

  for key, fn  in pairs(keymaps) do
    vim.keymap.set("n", key, function ()
      -- necessary because of possible bug
      return vim.api.nvim_get_current_buf() == print_panel.bufnr and fn()
    end, {
      silent = true,
      buffer = print_panel.bufnr,
    })
  end

  local id = a.nvim_create_augroup("Panel", {
    clear = false
  })

  a.nvim_create_autocmd({"TextChangedI", "TextChangedP"}, {
    callback = function ()
      require("copilot.extensions.panel").send_request({
        uri = "pb"
      })
    end,
    group = id,
  })

  a.nvim_create_autocmd("WinEnter", {
    callback = function ()
      if print_panel.entries then
        print_panel.select(print_panel.entries.current)
      end
    end,
    buffer = print_panel.bufnr,
    group = id,
  })

  a.nvim_create_autocmd("WinClosed", {
    pattern = { tostring(print_panel.win) },
    callback = function ()
      -- cleanup panel triggers
      a.nvim_create_augroup("Panel", { clear = true })
      handler.remove_handler_callback("PanelSolution", "pb")
      handler.remove_handler_callback("PanelSolutionsDone", "pb")
    end,
    once = true,
    group = id,
  })
end

return print_panel

-- if you add back numbering:
--
-- local add_prefix_spacing = function (str, number)
--   return string.rep(' ', number) .. str
-- end
--
-- local entry_str = "[" .. number .. "]"
-- for index, value in ipairs(lines) do
--   if index == 1 then
--     lines[index] = entry_str .. add_prefix_spacing(value, vim.o.shiftwidth)
--   else
--     lines[index] = add_prefix_spacing(value, vim.o.shiftwidth+entry_str:len())
--   end
-- end

