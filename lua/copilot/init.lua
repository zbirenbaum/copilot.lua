local M = { client_info = nil }
local client = require("copilot.client")
local defaults = {
  panel = { -- no config options yet
    enabled = true,
  },
  ft_disable = {},
  copilot_node_command = "node",
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
  server_opts_overrides = {},
}

local create_cmds = function (_)
  vim.api.nvim_create_user_command("CopilotDetach", function()
    local client_instance = require("copilot.util").get_copilot_client()
    local valid = client_instance and vim.lsp.buf_is_attached(0, client_instance.id)
    if not valid then return end
    vim.lsp.buf_detach_client(0, client_instance.id)
  end, {})

  vim.api.nvim_create_user_command("CopilotStop", function()
    local client_instance = require("copilot.util").get_copilot_client()
    if not client_instance then return end
    vim.lsp.stop_client(client_instance.id)
  end, {})

  vim.api.nvim_create_user_command("CopilotPanel", function ()
    local panel = require("copilot.extensions.panel").create()
    panel.send_request()
    require("copilot.extensions.print_panel").create(panel.buf)
  end, {})

  vim.api.nvim_create_user_command("CopilotAuth", function()
    require("copilot.util").auth()
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

    if user_config.panel.enabled then
      create_cmds(user_config)
    end

  end)
end

return M
