-- Helpers for testing the Node.js LSP adapter without system or installer I/O.
local M = {}

M.default_server_path = "/cache/copilot/1.527.5/js/generations/aaaaaaaa-generation/language-server.js"
M.custom_server_path = "custom/path/to/language-server.js"

---@param callback function
function M.install(callback)
  local installer = require("copilot.lsp.installer")
  local original_ensure = installer.ensure
  installer.ensure = function(server_type, install_callback)
    assert(server_type == "nodejs")
    install_callback(nil, M.default_server_path)
  end
  local ok, err = pcall(callback)
  installer.ensure = original_ensure
  if not ok then
    error(err)
  end
end

---@param stdout string
---@param code integer
---@param fail boolean
---@param callback function
---@return table|nil
function M.process(stdout, code, fail, callback)
  local captured_args = nil
  local original_vim_system = vim.system
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.system = function(cmd)
    captured_args = cmd
    if fail then
      error("Command failed")
    end
    return {
      wait = function()
        return { stdout = stdout .. "\n", code = code }
      end,
    }
  end
  local ok, err = pcall(callback)
  vim.system = original_vim_system
  if not ok then
    error(err)
  end
  return captured_args
end

M.invalid_node_version = "10.0.0"
M.valid_node_version_22 = "22.0.0"
M.valid_node_version_24 = "24.0.0"
M.valid_node_version_25 = "25.0.0"

function M.valid_node_22(callback)
  return M.process("v" .. M.valid_node_version_22, 0, false, callback)
end

function M.valid_node_24(callback)
  return M.process("v" .. M.valid_node_version_24, 0, false, callback)
end

function M.valid_node_25(callback)
  return M.process("v" .. M.valid_node_version_25, 0, false, callback)
end

function M.invalid_node(callback)
  return M.process("v" .. M.invalid_node_version, 0, false, callback)
end

---@param callback function
---@param node_function function|nil
function M.get_runtime_server_path(callback, node_function)
  (node_function or M.valid_node_25)(function()
    M.install(callback)
  end)
end

return M
