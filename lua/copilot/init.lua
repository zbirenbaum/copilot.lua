local M = { client_info = nil }
local client = require("copilot.client")
local highlight = require("copilot.highlight")
local panel = require("copilot.panel")
local suggestion = require("copilot.suggestion")
local defaults = {
  panel = {
    enabled = true,
    auto_refresh = false,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<M-CR>"
    }
  },
  suggestion = {
    enabled = true,
    auto_trigger = false,
    debounce = 75,
    keymap = {
      accept = "<M-l>",
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    }
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
    require("copilot.panel").open()
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
      panel.setup(user_config.panel)
      create_cmds(user_config)
    end

    if user_config.suggestion.enabled then
      suggestion.setup(user_config.suggestion)
    end
  end)

  highlight.setup()
end

return M
