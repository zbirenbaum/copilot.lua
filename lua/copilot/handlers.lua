local api = require("copilot.api")

---@deprecated
local handlers = {}

-- use `require("copilot.api").register_panel_handlers()`
---@deprecated
handlers.add_handler_callback = function(method, panelId, fn)
  api.panel.callback[method][panelId] = fn
end

-- use `require("copilot.api").unregister_panel_handlers()`
---@deprecated
handlers.remove_handler_callback = function(method, panelId)
  api.panel.callback[method][panelId] = nil
end

-- use `require("copilot.api").unregister_panel_handlers()`
---@deprecated
handlers.remove_all_name = function(panelId)
  api.unregister_panel_handlers(panelId)
end

return handlers
