---@alias RootDirFuncOrString string | fun(): string

local root_dir = {
  ---@type RootDirFuncOrString
  default = function()
    return vim.fs.dirname(vim.fs.find(".git", { upward = true })[1])
  end,
}

return root_dir
