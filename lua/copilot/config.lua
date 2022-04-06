local M = {}

local defaults = {
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
  on_attach = function()
    require("copilot_cmp")._on_insert_enter()
  end,
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
