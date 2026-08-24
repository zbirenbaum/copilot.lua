local logger = require("copilot.logger")
local installer = require("copilot.lsp.installer")

local M = {
  ---@class copilot_server_info
  ---@field path string
  ---@field filename string
  ---@field absolute_path string
  ---@field absolute_filepath string
  ---@field extracted_filename string
  copilot_server_info = nil,
  server_path = nil,
}

---@param client vim.lsp.Client|nil
---@return string
function M.get_server_info(client)
  local result = M.server_path or M.get_server_path()
  return client and result or result .. " not running"
end

---@return table
function M.get_execute_command()
  return { M.server_path or M.get_server_path(), "--stdio" }
end

---@return copilot_server_info
function M.get_copilot_server_info()
  if M.copilot_server_info then
    return M.copilot_server_info
  end
  M.copilot_server_info = {
    path = M.server_path or "",
    filename = M.server_path or "",
    absolute_path = M.server_path or "",
    absolute_filepath = M.server_path or "",
    extracted_filename = "",
  }
  return M.copilot_server_info
end

---@return string
function M.get_server_path()
  return M.get_copilot_server_info().absolute_filepath
end

---@param custom_server_path? string
---@param callback fun(err: string|nil)
function M.setup(custom_server_path, callback)
  if custom_server_path then
    if vim.fn.executable(custom_server_path) == 0 then
      local err = "copilot-language-server not found at " .. custom_server_path
      logger.error(err)
      callback(err)
      return
    end
    logger.debug("using custom copilot-language-server binary:", custom_server_path)
    M.server_path = custom_server_path
    M.copilot_server_info = {
      path = "",
      filename = "",
      absolute_path = "",
      absolute_filepath = custom_server_path,
      extracted_filename = "",
    }
    callback(nil)
    return
  end

  installer.ensure("binary", function(err, path)
    if err then
      callback(err)
      return
    end
    M.server_path = path
    callback(nil)
  end)
end

return M
