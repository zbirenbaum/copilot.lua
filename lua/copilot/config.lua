local M = {}

local defaults = {
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
}

M.params = {}

M.setup = function(options)
  if not options then
    M.params = defaults
  else
    for key, value in pairs(defaults) do
      M.params[key] = options[key] or value
    end
  end
end

return M
