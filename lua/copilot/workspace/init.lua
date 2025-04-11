local logger = require("copilot.logger")
local utils = require("copilot.workspace.utils")

local M = {}
---@class workspace_folder
---@field uri string The URI of the workspace folder
---@field name string The name of the workspace folder
function M.add(opts)
  local folder = opts.args
  if not folder or folder == "" then
    logger.error("folder is required to add a workspace_folder")
    return
  end

  folder = vim.fn.fnamemodify(folder, ":p")
  utils.add_workspace_folder(folder)
end

return M
