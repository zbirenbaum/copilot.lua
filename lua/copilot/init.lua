local M = { client_info = nil }
local client = require("copilot.client")

local defaults = {
  cmp = {
    method = "getPanelCompletions",
    max_results = 5,
  },
  extensions = {
    getPanelCompletions = function (max_results)
      local panel = require("copilot.extensions.panel").create(max_results)
      require("copilot_cmp").setup(panel.complete)
    end,
    getCompletionsCycling = function ()
      require("copilot_cmp").setup()
    end,
  },
  ft_disable = {},
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
  server_opts_overrides = {},
  settings = {
    advanced = {
      listCount = 10, -- #completions for panel
      inlineSuggestCount = 3, -- #completions for getCompletions
    }
  }
}

local config_handler = function(opts)
  local user_config = opts and vim.tbl_deep_extend("force", defaults, opts) or defaults
  return user_config
end

M.setup = function(opts)
  local user_config = config_handler(opts)
  vim.schedule(function () client.start(user_config) end)
end

return M
