local M = { setup_done = false }
local config = require("copilot.config")
local highlight = require("copilot.highlight")
local logger = require("copilot.logger")
local client = require("copilot.client")
local auth = require("copilot.auth")

local create_cmds = function()
  vim.api.nvim_create_user_command("CopilotDetach", function()
    if require("copilot.client").buf_is_attached(0) then
      vim.deprecate("':CopilotDetach'", "':Copilot detach'", "in future", "copilot.lua")
      vim.cmd("Copilot detach")
    end
  end, {})

  vim.api.nvim_create_user_command("CopilotStop", function()
    vim.deprecate("':CopilotStop'", "':Copilot disable'", "in future", "copilot.lua")
    vim.cmd("Copilot disable")
  end, {})

  vim.api.nvim_create_user_command("CopilotPanel", function()
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

  highlight.setup()

  local conf = config.setup(opts)
  if conf and conf.panel.enabled then
    create_cmds()
  end

  require("copilot.command").enable()
  logger.setup(conf.logger)

  logger.debug("active plugin config:", config)
  -- logged here to ensure the logger is setup
  logger.debug("active LSP config (may change runtime):", client.config)

  local token_env_set = (os.getenv("GITHUB_COPILOT_TOKEN") ~= nil) or (os.getenv("GH_COPILOT_TOKEN") ~= nil)

  if token_env_set then
    auth.signin()
  end

  M.setup_done = true
end

return M
