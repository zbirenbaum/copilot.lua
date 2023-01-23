local M = { setup_done = false }
local config = require("copilot.config")
local client = require("copilot.client")
local highlight = require("copilot.highlight")
local panel = require("copilot.panel")
local suggestion = require("copilot.suggestion")

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
    vim.deprecate("':CopilotPanel'", "':Copilot panel'", "in future", "copilot.lua")
    vim.cmd("Copilot panel")
  end, {})

  vim.api.nvim_create_user_command("CopilotAuth", function()
    vim.deprecate("':CopilotAuth'", "':Copilot auth'", "in future", "copilot.lua")
    vim.cmd("Copilot auth")
  end, {})
end

M.setup = function(opts)
  if M.setup_done then
    return
  end

  local conf = config.setup(opts)

  client.setup(conf)

  if conf.panel.enabled then
    panel.setup(conf.panel)
    create_cmds(conf)
  end

  if conf.suggestion.enabled then
    suggestion.setup(conf.suggestion)
  end

  highlight.setup()

  M.setup_done = true
end

return M
