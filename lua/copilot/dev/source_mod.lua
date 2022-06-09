local M = {}
local util = require("copilot.util")
local source = require("copilot_cmp.source")
local existing_matches = {}

local request_func = function (client, params)
  local request_result = nil
  return request_result
end

M.setup = function ()
  require("copilot_cmp")._on_insert_enter(source)
end

return M

  -- source.complete = function(self, params, callback)
  --   existing_matches[params.context.bufnr] = existing_matches[params.context.bufnr] or {}
  --   existing_matches[params.context.bufnr][params.context.cursor.row] = existing_matches[params.context.bufnr][params.context.cursor.row] or { IsIncomplete = true }
  --   local existing = existing_matches[params.context.bufnr][params.context.cursor.row]
  --   local has_complete = false
  --   client.request_sync(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
  --     if response and not vim.tbl_isempty(response.completions) then
  --       existing = vim.tbl_deep_extend("force", existing, self:format_completions(params, response.completions))
  --       has_complete = true
  --     end
  --     vim.schedule(function() callback(existing) end)
  --   end)
  --   if not has_complete then
  --     callback(existing)
  --   end
  -- end
