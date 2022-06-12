local util = require("copilot.util")
local format = require("copilot_cmp.format")
local handler = require("copilot.handlers")
local print_buf = require("copilot.print_panel")

local panel = {
  method = "getPanelCompletions",
  usecmp = false,
  buf = "",
  uri = "",
}

local existing_matches= {}

panel.send_request = function (callback)
  local completion_params = util.get_completion_params()
  completion_params.panelId = panel.uri
  callback = callback or function () end
  vim.lsp.buf_request(0, panel.method, completion_params, callback)
end

local verify_existing = function (context)
  existing_matches[context.bufnr] = existing_matches[context.bufnr] or {}
  existing_matches[context.bufnr][context.cursor.row] = existing_matches[context.bufnr][context.cursor.row] or {}
end

panel.complete = vim.schedule_wrap(function (_, params, callback)
  local context = params.context
  verify_existing(context)

  local add_completion = function (result)
    result.text = result.displayText
    local formatted = format.format_item(params, result)
    existing_matches[context.bufnr][context.cursor.row][formatted.label] = formatted
    callback({
      isIncomplete = true,
      items = vim.tbl_values(existing_matches[context.bufnr][context.cursor.row])
    })
  end

  local completed = function ()
    callback({
      isIncomplete = false,
      items = vim.tbl_values(existing_matches[context.bufnr][context.cursor.row])
    })
  end

  handler.add_handler_callback("PanelSolution", "cmp", add_completion)
  handler.add_handler_callback("PanelSolutionsDone", "cmp", completed)

  panel.send_request()

  callback({ isIncomplete = true })
end)

function panel.create (opts)
  panel = vim.tbl_deep_extend("force", panel, opts or {})
  panel.buf = type(panel.uri) == "number" or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(panel.buf, "copilot:///" .. tostring(panel.buf))
  panel.uri = vim.uri_from_bufnr(panel.buf)

  vim.api.nvim_create_user_command("CopilotPanel", function ()
    print_buf.create(panel.buf)
    local items = {}
    handler.add_handler_callback("PanelSolution", "pb", function (result)
      local formatted = format.deindent(result.displayText)
      items[formatted] = 1
    end)
    handler.add_handler_callback("PanelSolutionsDone", "pb", function ()
      local item_list = vim.tbl_add_reverse_lookup(vim.tbl_keys(items))
      local result_text = vim.tbl_flatten(vim.tbl_map(function(v)
        local s = vim.fn.split(v, '\n')
        local text = vim.tbl_map(function (t)
          local number_string = "[" .. item_list[v] .. "]"
          local str = (s[1] == t and number_string .. string.rep(' ', vim.o.shiftwidth)) or string.rep(' ', vim.o.shiftwidth+string.len(number_string))
          return str .. t
        end, s)
        table.insert(text, '')
        return text
      end, item_list))
      print_buf.set_text(result_text)
      items = {}
    end)
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = { tostring(print_buf.win) },
      callback = function ()
        handler.remove_handler_callback("PanelSolution", "pb")
        handler.remove_handler_callback("PanelSolutionsDone", "pb")
      end,
      once = true,
    })
  end, {})
  return panel
end

return panel
