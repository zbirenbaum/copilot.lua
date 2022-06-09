local M = {}

local oldprint = print
local print = function (args)
  if type(args) == "table" then
    oldprint(vim.inspect(args))
  else
    oldprint(args)
  end
end

local format_pos = function()
  local pos = vim.api.nvim_win_get_cursor(0)
  return { character = pos[2], line = pos[1] - 1 }
end

local get_relfile = function()
  local file, _ = string.gsub(vim.api.nvim_buf_get_name(0), vim.loop.cwd() .. "/", "")
  return file
end

M.find_copilot_client = function()
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == "copilot" then
      return client.id
    end
  end
end

M.find_copilot_buf_client = function()
  for _, client in ipairs(vim.lsp.buf_get_clients(0)) do
    if client.name == "copilot" then
      return client.id
    end
  end
end


M.get_completion_params = function(method)
  local rel_path = get_relfile()
  local uri = vim.uri_from_bufnr(0)
  local params = {
    options = vim.empty_dict(),
    panelId = (method == "getPanelCompletions") and "fuckyou" or nil,
    doc = {
      source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"),
      relativePath = rel_path,
      languageId = vim.bo.filetype,
      insertSpaces = true,
      tabsize = vim.bo.shiftwidth,
      indentsize = vim.bo.shiftwidth,
      position = format_pos(),
      path = vim.api.nvim_buf_get_name(0),
      uri = uri,
    },
    textDocument = {
      languageId = vim.bo.filetype,
      relativePath = rel_path,
      uri = uri,
    }
  }
  return params
end

M.get_copilot_path = function(plugin_path)
  for _, loc in ipairs({ "/opt", "/start", "" }) do
    local copilot_path = plugin_path .. loc .. "/copilot.lua/copilot/index.js"
    if vim.fn.filereadable(copilot_path) ~= 0 then
      return copilot_path
    end
  end
end

local function completion_handler(_, result, _, _)
  print(vim.inspect(result))
end

M.register_completion_handler = function(handler)
  if handler then
    completion_handler = handler
  end
end

M.send_completion_request = function()
  local params = M.get_completion_params()
  vim.lsp.buf_request(0, "getCompletions", params, completion_handler)
end

M.create_request_autocmd = function(group)
  vim.api.nvim_create_autocmd(group, { callback = M.send_completion_request })
end

M.panel = function (_, solutions, c)
  print(#solutions)
  print(c)
end

M.panel_done = function (a, b, c)
  print(a)
  print(b)
  print(c)
end

M.get_panel = function (callback, notify_reply_callback)
  local client = M.find_copilot_client()
  local params = M.get_completion_params("getPanelCompletions")
  client.rpc.request("getPanelCompletions", params, callback, notify_reply_callback)
end

return M
