local logger = require("copilot.logger")
local util = require("copilot.util")

local M = {
  ---@class copilot_nodejs_server_info
  ---@type string|string[]
  node_command = nil,
  ---@type string
  server_path = nil,
  initialization_failed = false,
}


---@return string node_version
---@return nil|string node_version_error
function M.get_node_version()
  if not M.node_version then
    local version_cmd = util.append_command(M.node_command, "--version")

    local node_version_major = 0
    local node_version = ""
    local cmd_exit_code = -1
    local cmd_output = "[no output]"
    local ok, process = pcall(vim.system, version_cmd)

    if ok and process then
      local result = process:wait()
      cmd_output = result.stdout or cmd_output
      cmd_exit_code = result.code

      if cmd_output and cmd_output ~= "[no output]" then
        node_version = string.match(cmd_output, "^v(%S+)") or node_version
        node_version_major = tonumber(string.match(node_version, "^(%d+)%.")) or node_version_major
      end
    end

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

    M.node_version = node_version
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
  return util.append_command(M.node_command, { M.server_path or M.get_server_path(), "--stdio" })
end

---@param node_command? string|string[]
---@param custom_server_path? string
---@return boolean
function M.setup(node_command, custom_server_path)
  M.node_command = node_command or "node"

  if not M.validate_node_version() or not M.init_agent_path(custom_server_path) then
    return false
  end

  return true
end

return M
