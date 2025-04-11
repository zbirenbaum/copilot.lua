---@alias RootDirFuncOrString string | fun(): string

local root_dir = {
  ---@type RootDirFuncOrString
  default = function()
    return vim.fs.dirname(vim.fs.find(".git", { upward = true })[1])
  end,
}

---@param config RootDirFuncOrString
function root_dir.validate(config)
  vim.validate("root_dir", config, { "string", "function" })
end

return root_dir
