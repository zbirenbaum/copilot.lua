local existing_matches = {}
local util = require("copilot.util")
local panel_printer = require("copilot.print_buf")
local panel_results = {}

local api = {
  client_id = nil,
  client = nil,
}
api.set_client_info = function (client_id)
  api.client_id = client_id
  api.client = vim.lsp.get_client_by_id(client_id)
  return api.client_id ~= nil
end

api.setup = function ()
  local id = util.find_copilot_client()
  api.set_client_info(id)
end

local reply_callback = function ()
end
api.panel = {
  save = function (_, solution)
    if solution and type(solution) == "table" then
      panel_results[#panel_results+1] = solution
    end
    print(#solution)
  end,

  open = function () require("copilot.panel").init() end,
  cmp = function ()
  end
  -- cmp = function (source, params, callback)
  --   if not client then return end
  --   local sent, req_id = client.rpc.request("getPanelCompletions", req_params, nil, reply_callback)
  --   vim.lsp.buf_request(0, "getPanelCompletions", req_params, function(_, response)
  --     -- local timer = vim.loop.new_timer()
  --     if response and not vim.tbl_isempty(panel_results) then
  --       for i, v in ipairs(panel_results) do
  --         print(i)
  --         print(v)
  --       end
  --     end
  --   end)
  -- end,

  -- print = function (_, solutions)
  --   if type(solutions) == "table" then
  --     panel_printer.print(solutions)
  --   end
  -- end,
      -- timer:start(0, 100, vim.schedule_wrap(function()
          -- timer:stop()
          -- local entries = source:format_completions(params, panel_results)
          -- vim.schedule(function()
          --   print(entries)
          --   -- callback(entries)
          --   panel_results = {}
          -- end)
        -- end
      -- end))
  -- cmp = function (source, params, callback)
  --   local entries = {}
  --   if panel_results then
  --     entries = source:format_completions(params, panel_results)
  --     vim.schedule(function() callback(entries) end)
  --     panel_results = nil
  --   else
  --     callback({ isIncomplete = true })
  --   end
  -- end
}

vim.api.nvim_create_user_command("CopilotPanel", function ()
  api.panel.open()
end, {})

local function verify_existing (params)
  existing_matches[params.context.bufnr] = existing_matches[params.context.bufnr] or {}
  existing_matches[params.context.bufnr][params.context.cursor.row] = existing_matches[params.context.bufnr][params.context.cursor.row] or { IsIncomplete = true }
  local existing = existing_matches[params.context.bufnr][params.context.cursor.row]
  return existing
end

api.complete_cycling = function (source, params, callback)
  local existing = verify_existing(params)
  local has_complete = false
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if response and not vim.tbl_isempty(response.completions) then
      existing = vim.tbl_deep_extend("force", existing, source:format_completions(params, response.completions))
      has_complete = true
    end
    vim.schedule(function() callback(existing) end)
  end)
  if not has_complete then
    callback(existing)
  end
end

return api
