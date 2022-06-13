local M = { client_info = nil }
local client = require("copilot.client")

local defaults = {
  cmp = {
    method = "getCompletionsCycling",
    max_results = 5,
  },
  extensions = {
    getPanelCompletions = function ()
      require("copilot_cmp").setup(require("copilot.panel").complete)
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
  require("copilot.extensions.panel").create()
  vim.schedule(function () client.start(user_config) end)
end

return M
