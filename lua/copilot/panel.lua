local util = require("copilot.util")
local Panel = {}

local results_callback = function (err, result)
  if err then return end
  if result then print(vim.inspect(result)) end
end


local notify_callback = function (err, result)
  if err then
    return 
  end
end
function Panel:send_request()
  if not self.client then return end
  local params = util.get_completion_params(self.method)
  local sent, req_id = self.request(self.method, params, results_callback, notify_callback)
  self.requests[req_id] = sent and {}
end

function Panel:new (client_id)
  setmetatable({}, self)
  self.client_id = client_id or util.find_copilot_client()
  self.client = vim.lsp.get_client_by_id(self.client_id)
  self.results = {}
  self.request = self.client.rpc.request
  self.method = "getPanelCompletions"
  self.__index = function (i) return self.results[i] end
  return self
end

