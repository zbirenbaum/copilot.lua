-- these are helper functions for testing the nodejs LSP integration
-- they stub out system interactions for verifying access to node and the LSP script

M = {}

M.default_server_path = "copilot/js/language-server.js"
M.custom_server_path = "custom/path/to/language-server.js"

---@param stdout string the stdout that will be returned by the stubbed vim.system
---@param code integer the exit code that will be returned by the stubbed vim.system
---@param fail boolean if true, vim.system will error when called
---@param callback function the function to call while vim.system is stubbed
---@return table|nil captured_args -- the arguments vim.system was called with
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
        return {
          stdout = stdout .. "\n",
          code = code,
        }
      end,
    }
  end
  -- wrap callback in pcall to ensure vim.system is restored if callback errors
  local ok, err = pcall(callback)
  vim.system = original_vim_system
  if not ok then
    error(err)
  end
  return captured_args
end

M.valid_node_version = "20.0.0"
M.invalid_node_version = "10.0.0"

---Convenience wrapper for Stub.process for a valid Node.js version (>= 20)
function M.valid_node(callback)
  return M.process("v" .. M.valid_node_version, 0, false, callback)
end

---Convenience wrapper for Stub.process for an invalid Node.js version (< 20)
function M.invalid_node(callback)
  return M.process("v" .. M.invalid_node_version, 0, false, callback)
end

---@param callback function the function to call while vim.api.nvim_get_runtime_file is stubbed
---@return string|nil captured_path -- the path vim.api.nvim_get_runtime_file was called with
function M.get_runtime_server_path(callback)
  local captured_path = nil

  local original_get_file = vim.api.nvim_get_runtime_file
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim_get_runtime_file = function(path)
    captured_path = path
    return { vim.fn.expand(M.default_server_path) }
  end

  local original_filereadable = vim.fn.filereadable
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.filereadable = function()
    return 1
  end

  -- stub valid node version for callback so setup() succeeds
  M.valid_node(function()
    -- wrap callback in pcall to ensure vim.api.nvim_get_runtime_file is restored if callback errors
    local ok, err = pcall(callback)
    vim.api.nvim_get_runtime_file = original_get_file
    vim.fn.filereadable = original_filereadable
    if not ok then
      error(err)
    end
  end)

  return captured_path
end

return M
