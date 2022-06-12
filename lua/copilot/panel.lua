local util = require("copilot.util")
local format = require("copilot_cmp.format")

local panel = {
  method = "getPanelCompletions",
  usecmp = false,
  cache_line = true,
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

panel.complete = vim.schedule_wrap(function (_, params, callback)
  local context = params.context
  existing_matches[context.bufnr] = existing_matches[context.bufnr] or {}
  existing_matches[context.bufnr][context.cursor.row] = existing_matches[context.bufnr][context.cursor.row] or {}

  local add_completion = function (result)
    if result then
      result.text = result.displayText
      local formatted = format.format_item(params, result)
      existing_matches[context.bufnr][context.cursor.row][formatted.label] = formatted
      vim.schedule(function() callback({
        isIncomplete = true,
        items = vim.tbl_values(existing_matches[context.bufnr][context.cursor.row])
      }) end)
    end
  end

  local completed = function ()
    vim.schedule(function() callback({
      isIncomplete = false,
      items = vim.tbl_values(existing_matches[context.bufnr][context.cursor.row])
    }) end)
    if not panel.cache_line then
      existing_matches[context.bufnr][context.cursor.row] = {}
    end
  end

  local handler = require("copilot.handlers").add_handler_callback
  handler("PanelSolution", "cmp", add_completion)
  handler("PanelSolutionsDone", "cmp", completed)

  panel.send_request()

  callback({ isIncomplete = true })
end)

function panel.create (opts)
  panel = vim.tbl_deep_extend("force", panel, opts or {})
  panel.buf = type(panel.uri) == "number" or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(panel.buf, "copilot:///" .. tostring(panel.buf))
  panel.uri = vim.uri_from_bufnr(panel.buf)
  vim.api.nvim_create_user_command("CopilotPanel", function ()
    local panel_suggestions = {}
    local handlers = require("copilot.handlers")
    handlers.add_handler_callback("PanelSolution", "print", function (result)
      table.insert(panel_suggestions, format.clean_insertion(result.displayText))
    end)
    handlers.add_handler_callback("PanelSolutionsDone", "print", function ()
      local print_buf = require("copilot.print_buf").init()
      print_buf.print(panel_suggestions)
      handlers.remove_handler_callback("PanelSolution", "print")
      handlers.remove_handler_callback("PanelSolutionsDone", "print")
    end)
    panel.send_request()
  end, {})
  return panel
end

return panel
