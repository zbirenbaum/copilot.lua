local M = {}

---@param _ vim.lsp.Client|nil
---@return string
function M.get_server_info(_)
  return "mocked"
end

function M.get_execute_command()
  return require("tests.stubs.lsp_server").server
end

function M.get_cmd_env()
  return {}
end

function M.setup(_, _, callback)
  callback(nil)
end

return M
