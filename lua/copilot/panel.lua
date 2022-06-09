local source = require("copilot_cmp.source")
local panel = {
  n_results = 5,
  ready = {}
}

local util = require("copilot.util")
local completions = require("copilot_cmp")

local results_callback = function (err, result)
  panel.n_results = result.solutionCountTarget
end

local notify_callback = function (err, result)
end

panel.save_completions = function (_, solution)
  if solution then
    local found = false
    for i, item in ipairs(panel.results) do
      if item.displayText == solution.displayText then
        panel.results[i] = not found and solution or nil
        found = true
      end
    end
    if not found then table.insert(panel.results, solution) end
  end
end

function panel.init (client_info)
  panel.client_id = client_info.client_id or util.find_copilot_client()
  panel.client = client_info and client_info.client
  panel.results = {}
  panel.cur_req = nil
  panel.method = "getPanelCompletions"
  panel.__index = function (i) return panel.results[i] end
  source.complete = function (_, params, callback)
    vim.lsp.buf_request(0, panel.method, util.get_completion_params(panel.method), function(err, result)
      if result then
        if panel.results and #panel.results >= 0 then
          local entries = source.format_completions(_, params, panel.results)
          callback(entries)
          panel.results = {}
        else
          callback({ isIncomplete = true })
        end
      end
    end)
  end
  return panel
end

return panel
