local copilot = {}
local util = require("copilot.util")



function copilot:get_panel_solutions (params, callback, notify_reply_callback)
  local sent, id = self.client.rpc.request("getPanelCompletions", params, callback, notify_reply_callback)
end

function copilot:request(method, callback, notify_reply_callback)
  local req_params = util.get_completion_params(method)
end

copilot.new = function()

return copilot
