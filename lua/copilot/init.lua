local M = { client_info = nil }
local client = require("copilot.client")

local defaults = {
  cmp = {
    enabled = true,
    method = "getPanelCompletions",
  },
  panel = { -- no config options yet
    enabled = true,
  },
  ft_disable = {},
  server_opts_overrides = {},
}

local create_cmds = function (_)
  vim.api.nvim_create_user_command("CopilotPanel", function ()
    local panel = require("copilot.extensions.panel").create()
    panel.send_request()
    require("copilot.extensions.print_panel").create(panel.buf)
  end, {})
end

local config_handler = function(opts)
  local user_config = opts and vim.tbl_deep_extend("force", defaults, opts) or defaults
  return user_config
end

M.setup = function(opts)
  local user_config = config_handler(opts)
  vim.schedule(function ()
    client.start(user_config)

    if user_config.cmp.enabled then
      require("copilot_cmp").setup(user_config.cmp.method)
    end

    if user_config.panel.enabled then
      create_cmds(user_config)
    end

  end)
end

return M
