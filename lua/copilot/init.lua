local M = { setup_done = false }
local highlight = require("copilot.highlight")
local logger = require("copilot.logger")
local client = require("copilot.client")
local config = require("copilot.config")

M.setup = function(opts)
  if vim.fn.has("nvim-0.11") == 0 then
    vim.notify_once(
      "[copilot.lua] Neovim 0.11+ will soon be required. Please upgrade your Neovim version if you wish to keep using this plugin.",
      vim.log.levels.WARN
    )
    return
  end

  if M.setup_done then
    return
  end

  highlight.setup()
  config.merge_with_user_configs(opts)
  logger.setup(config.logger)
  logger.debug("active plugin config:", config)
  require("copilot.command").enable()
  -- logged here to ensure the logger is setup
  logger.debug("active LSP config (may change runtime):", client.config)

  M.setup_done = true
end

return M
