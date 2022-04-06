local config = require("copilot.config")
local M = {}

M.setup = function(params)
  config.setup(params)
  config.params.plugin_manager_path = vim.fn.expand(config.params.plugin_manager_path) -- resolve wildcard and variable containing paths
  require("copilot.copilot_handler").start(config.params)
end

return M
