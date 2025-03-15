local mod = {}
---@class workspace_folder
---@field uri string The URI of the workspace folder
---@field name string The name of the workspace folder
function mod.add(opts)
  local folder = opts.args
  if not folder or folder == "" then
    error("Folder is required to add a workspace_folder")
  end

  folder = vim.fn.fnamemodify(folder, ":p")

  require("copilot.client").add_workspace_folder(folder)
end

return mod
