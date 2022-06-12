local M = { client_info = nil }
local client = require("copilot.client")
local lsp = vim.lsp

local defaults = {
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
  server_opts_overrides = {},
  ft_disable = {},
  cmp_method = "getCompletionsCycling"
}

local config_handler = function(opts)
  local user_config = opts and vim.tbl_deep_extend("force", defaults, opts) or defaults
  return user_config
end

local set_client_info = function(client_id)
  M.client_info = {
    client_id = client_id,
    client = lsp.get_client_by_id(client_id)
  }
end

local get_client_info = function ()
  return M.client_info
end

M.setup = function(opts)
  local user_config = config_handler(opts)
  vim.schedule(function () client.start(user_config) end)
  if user_config.cmp_method == "getPanelCompletions" then
    local panel = require("copilot.panel").create()
    require("copilot_cmp").setup(panel.complete)
  elseif user_config.cmp_method == "getCompletionsCycling" then
    require("copilot_cmp").setup()
  end
end

return M
