local logger = require("copilot.logger")

local M = {
  binary = require("copilot.lsp.binary"),
  nodejs = require("copilot.lsp.nodejs"),
  ---@type ServerConfig
  config = nil,
}

---@param client vim.lsp.Client|nil
---@return string
function M.get_server_info(client)
  if M.config and M[M.config.type] then
    return M[M.config.type].get_server_info(client)
  end
  return ""
end

---@return table
function M.get_execute_command()
  if M.config and M[M.config.type] then
    return M[M.config.type].get_execute_command()
  end
  return {}
end

---@param server_config ServerConfig
---@param copilot_node_command string
---@param callback fun(err: string|nil)
function M.setup(server_config, copilot_node_command, callback)
  if not server_config then
    local err = "server_config is required"
    logger.error(err)
    callback(err)
    return
  end

  M.config = server_config
  if server_config.type == "nodejs" then
    M.nodejs.setup(copilot_node_command, server_config.custom_server_filepath, callback)
  elseif server_config.type == "binary" then
    M.binary.setup(server_config.custom_server_filepath, callback)
  else
    local err = "invalid server_config.type"
    logger.error(err)
    callback(err)
  end
end

return M
