local logger = require("copilot.logger")
local util = require("copilot.util")
local installer = require("copilot.lsp.installer")

local M = {
  ---@class copilot_nodejs_server_info
  ---@type string|string[]
  node_command = nil,
  ---@type string
  server_path = nil,
}

---@return string node_version
---@return nil|string node_version_error
local function probe_node_version(node_command)
  local version_cmd = util.append_command(node_command, "--version")

  local node_version_major = 0
  local node_version = ""
  local cmd_exit_code = -1
  local cmd_output = "[no output]"
  local ok, process = pcall(vim.system, version_cmd)

  if ok and process then
    local result = process:wait()
    cmd_output = result.stdout
    if not cmd_output or cmd_output == "" then
      cmd_output = result.stderr or cmd_output or "[no output]"
    end
    cmd_exit_code = result.code

    if cmd_exit_code == 0 and cmd_output ~= "[no output]" then
      node_version = string.match(cmd_output, "^v(%S+)") or node_version
      node_version_major = tonumber(string.match(node_version, "^(%d+)%.")) or node_version_major
    end
  elseif not ok then
    cmd_output = tostring(process)
  end

  local node_version_error
  if node_version_major == 0 then
    node_version_error = table.concat({
      "Could not determine Node.js version",
      "-----------",
      "(exit code) " .. tostring(cmd_exit_code),
      "   (output) " .. cmd_output,
      "-----------",
    }, "\n")
  elseif node_version_major < 22 then
    node_version_error = string.format("Node.js version 22 or newer required but found %s", node_version)
  end

  return node_version, node_version_error
end

---@param node_command string|string[]
---@return string node_version
---@return nil|string node_version_error
function M.get_node_version_for_command(node_command)
  return probe_node_version(node_command)
end

function M.get_node_version()
  if M.node_version == nil or not vim.deep_equal(M.node_version_command, M.node_command) then
    M.node_version, M.node_version_error = probe_node_version(M.node_command)
    local node_command = M.node_command
    if type(node_command) == "table" then
      M.node_version_command = vim.deepcopy(node_command)
    else
      M.node_version_command = node_command
    end
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
  local args = util.get_node_args(M.server_path or M.get_server_path(), "nodejs", M.node_version)

  return util.append_command(M.node_command, args)
end

---@param node_command? string|string[]
---@param custom_server_path? string
---@param callback fun(err: string|nil)
function M.setup(node_command, custom_server_path, callback)
  M.node_command = node_command or "node"
  M.node_version = nil
  M.node_version_error = nil
  M.node_version_command = nil

  if not M.validate_node_version() then
    callback(M.node_version_error)
    return
  end

  if custom_server_path then
    if vim.fn.filereadable(custom_server_path) == 0 and vim.fn.executable(custom_server_path) == 0 then
      local err = "copilot-language-server not found at " .. custom_server_path
      logger.error(err)
      callback(err)
      return
    end
    M.server_path = custom_server_path
    callback(nil)
    return true
  end

  installer.ensure("nodejs", function(err, path)
    if err then
      callback(err)
      return
    end
    M.server_path = path
    callback(nil)
  end)
end

return M
