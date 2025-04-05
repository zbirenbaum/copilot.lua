local M = { setup_done = false }
local highlight = require("copilot.highlight")
local logger = require("copilot.logger")
local client = require("copilot.client")
local auth = require("copilot.auth")
local config = require("copilot.config")

M.setup = function(opts)
  if M.setup_done then
    return
  end

  highlight.setup()
  config.merge_with_user_configs(opts)

  require("copilot.command").enable()
  logger.setup(config.logger)

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
