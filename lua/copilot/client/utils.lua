local M = {}

---@param config_root_dir RootDirFuncOrString
function M.get_root_dir(config_root_dir)
  local root_dir --[[@as string]]

  if type(config_root_dir) == "function" then
    root_dir = config_root_dir()
  else
    root_dir = config_root_dir
  end

  if not root_dir or root_dir == "" then
    root_dir = "."
  end

  root_dir = vim.fn.fnamemodify(root_dir, ":p:h")
  return root_dir
end

return M
