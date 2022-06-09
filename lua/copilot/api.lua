local util = require("copilot.util")
local api = {}

api.panel = { --add print buf with highlighting needed
  create = function ()
    local client_id = util.find_copilot_client()
    local client = vim.lsp.get_client_by_id(client_id)
    return client_id and require("copilot.panel").init({
      client_id = client_id, client = client
    }) or false
  end
}

return api
