local M = {}

---@return boolean
function M.initialization_failed()
  return false
end

---@return boolean
function M.init()
  return true
end

---@param _ vim.lsp.Client|nil
---@return string
function M.get_server_info(_)
  return "mocked"
end

function M.get_execute_command()
  return require("tests.stubs.lsp_server").server
end

function M.setup(_, _)
  return true
end

return M
