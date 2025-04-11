local logger = require("copilot.logger")

local M = {
  ---@class copilot_nodejs_server_info
  ---@type string
  node_command = nil,
  ---@type string
  server_path = nil,
  initialization_failed = false,
}

---@return string node_version
---@return nil|string node_version_error
function M.get_node_version()
  if not M.node_version then
    local cmd = { M.node_command, "--version" }
    local cmd_output_table = vim.fn.executable(M.node_command) == 1 and vim.fn.systemlist(cmd, nil, 0) or { "" }
    local cmd_output = cmd_output_table[#cmd_output_table]
    local cmd_exit_code = vim.v.shell_error

    local node_version = string.match(cmd_output, "^v(%S+)") or ""
    local node_version_major = tonumber(string.match(node_version, "^(%d+)%.")) or 0

    if node_version_major == 0 then
      M.node_version_error = table.concat({
        "Could not determine Node.js version",
        "-----------",
        "(exit code) " .. tostring(cmd_exit_code),
        "   (output) " .. cmd_output,
        "-----------",
      }, "\n")
    elseif node_version_major < 20 then
      M.node_version_error = string.format("Node.js version 20 or newer required but found %s", node_version)
    end

    M.node_version = node_version or ""
  end

  return M.node_version, M.node_version_error
end

---@param _ vim.lsp.Client|nil
---@return string
function M.get_server_info(_)
  return string.format("Node.js %s\nLanguage server: %s\n", M.get_node_version(), M.server_path)
end

---@return boolean
function M.validate_node_version()
  local _, node_version_error = M.get_node_version()

  if node_version_error then
    logger.error(node_version_error)
    return false
  end

  return true
end

function M.node_exists()
  local node_exists = vim.fn.executable(M.node_command) == 1

  if not node_exists then
    logger.error("node.js is not installed or not in PATH")
    return false
  end

  return true
end

---@param server_path? string
---@return boolean
function M.init_agent_path(server_path)
  local agent_path = server_path or vim.api.nvim_get_runtime_file("copilot/js/language-server.js", false)[1]

  if not agent_path or vim.fn.filereadable(agent_path) == 0 then
    logger.error(string.format("could not find server (bad install?) : %s", tostring(agent_path)))
    M.initialization_failed = true
    return false
  end

  M.server_path = agent_path
  return true
end

---@return string|nil
function M.get_server_path()
  if not M.server_path then
    logger.error("server path is not set")
    return nil
  end

  return M.server_path
end

---@return table
function M.get_execute_command()
  return {
    M.node_command,
    M.server_path or M.get_server_path(),
    "--stdio",
  }
end

---@param node_command? string
---@param custom_server_path? string
---@return boolean
function M.setup(node_command, custom_server_path)
  M.node_command = node_command or "node"

  if not M.node_exists() or not M.validate_node_version() or not M.init_agent_path(custom_server_path) then
    return false
  end

  return true
end

return M
