local logger = require("copilot.logger")

local M = {
  binary = require("copilot/lsp/binary"),
  nodejs = require("copilot/lsp/nodejs"),
  ---@type ServerConfig
  config = nil,
}

---@return boolean
function M.initialization_failed()
  if M.config.type == "nodejs" then
    return M.nodejs.initialization_failed
  elseif M.config.type == "binary" then
    return M.binary.initialization_failed
  end

  return true
end

---@return boolean
function M.init()
  if M.config.type == "nodejs" then
    return M.nodejs.init()
  elseif M.config.type == "binary" then
    return M.binary.init()
  end

  return false
end

---@param client vim.lsp.Client|nil
---@return string
function M.get_server_info(client)
  if M.config.type == "nodejs" then
    return M.nodejs.get_server_info(client)
  elseif M.config.type == "binary" then
    return M.binary.get_server_info(client)
  end

  return ""
end

---@return table
function M.get_execute_command()
  if M.config.type == "nodejs" then
    return M.nodejs.get_execute_command()
  elseif M.config.type == "binary" then
    return M.binary.get_execute_command()
  end

  return {}
end

---@param server_config ServerConfig
---@param copilot_node_command string
function M.setup(server_config, copilot_node_command)
  if not server_config then
    logger.error("server_config is required")
  end

  if server_config.type == "nodejs" then
    M.nodejs.setup(copilot_node_command, server_config.custom_server_filepath)
  elseif server_config.type == "binary" then
    M.binary.setup(server_config.custom_server_filepath)
  else
    logger.error("invalid server_config.type")
  end

  M.config = server_config
end

return M
