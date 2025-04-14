local logger = require("copilot.logger")
local api = require("copilot.api")
local config = require("copilot.config")
local c = require("copilot.client")
local M = {}

function M.add_workspace_folder(folder_path)
  if type(folder_path) ~= "string" then
    logger.error("workspace folder path must be a string")
    return false
  end

  if vim.fn.isdirectory(folder_path) ~= 1 then
    logger.error("invalid workspace folder: " .. folder_path)
    return false
  end

  folder_path = vim.fn.fnamemodify(folder_path, ":p")

  --- @type workspace_folder
  local workspace_folder = {
    uri = vim.uri_from_fname(folder_path),
    name = folder_path,
  }

  local workspace_folders = config.workspace_folders
  if not workspace_folders then
    workspace_folders = {}
  end

  for _, existing_folder in ipairs(workspace_folders) do
    if existing_folder == folder_path then
      return
    end
  end

  table.insert(workspace_folders, { folder_path })
  config.workspace_folders = workspace_folders

  local client = c.get()
  if client and client.initialized then
    api.notify(client, "workspace/didChangeWorkspaceFolders", {
      event = {
        added = { workspace_folder },
        removed = {},
      },
    })
    logger.notify("added workspace folder: " .. folder_path)
  else
    logger.notify("workspace folder will be added on next session: " .. folder_path)
  end

  return true
end

return M
