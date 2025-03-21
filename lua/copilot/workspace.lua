local logger = require("copilot.logger")
local client = require("copilot.client")

local mod = {}
---@class workspace_folder
---@field uri string The URI of the workspace folder
---@field name string The name of the workspace folder
function mod.add(opts)
  local folder = opts.args
  if not folder or folder == "" then
    logger.error("folder is required to add a workspace_folder")
    return
  end

  folder = vim.fn.fnamemodify(folder, ":p")
  client.add_workspace_folder(folder)
end

return mod
