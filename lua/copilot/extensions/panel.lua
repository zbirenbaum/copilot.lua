local util = require("copilot.util")
local format = require("copilot_cmp.format")
local handler = require("copilot.handlers")
local print_buf = require("copilot.extensions.print_panel")

local panel = {
  method = "getPanelCompletions",
  usecmp = false,
  client = vim.lsp.get_active_clients({name="copilot"})[1],
  buf = "",
  uri = "copilot:///placeholder",
  requests = {},
}

panel.send_request = function (callback)
  panel.client = not vim.tbl_isempty(panel.client) and panel.client or vim.lsp.get_active_clients({name="copilot"})[1]
  if not panel.client then return end
  local completion_params = util.get_completion_params()
  completion_params.panelId = panel.uri
  callback = callback or function () end
  return panel.client.rpc.request(panel.method, completion_params, callback)
end

local existing_matches= {}

local verify_existing = function (context)
  existing_matches[context.bufnr] = existing_matches[context.bufnr] or {}
  existing_matches[context.bufnr][context.cursor.row] = existing_matches[context.bufnr][context.cursor.row] or {}
end

panel.complete = vim.schedule_wrap(function (_, params, callback)
  local context = params.context
  verify_existing(context)
  local sent, id

  local add_completion = function (result)
    result.text = result.displayText
    local formatted = format.format_item(params, result)
    existing_matches[context.bufnr][context.cursor.row][formatted.label] = formatted
  end

  local completed = function ()
    callback({
      isIncomplete = false,
      items = vim.tbl_values(existing_matches[context.bufnr][context.cursor.row])
    })
  end

  handler.add_handler_callback("PanelSolution", "cmp", add_completion)
  handler.add_handler_callback("PanelSolutionsDone", "cmp", completed)
  if sent and id then panel.client.rpc.cancel_request(id) end
  sent, id = panel.send_request()
  callback({ isIncomplete = true })
end)

function panel.create (max_results)
  panel.max_results = max_results or 10
  panel.buf = type(panel.uri) == "number" or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(panel.buf, "copilot:///" .. tostring(panel.buf))
  panel.uri = vim.uri_from_bufnr(panel.buf)
  panel.client = vim.lsp.get_active_clients({name="copilot"})

  vim.api.nvim_create_user_command("CopilotPanel", function ()
    panel.send_request()
    print_buf.create(panel.buf)
  end, {})

  return panel
end

return panel
