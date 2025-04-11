local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local status = require("copilot.status")
local panel = require("copilot.panel")

local M = {}

function M.get_handlers()
  local handlers = {
    -- TODO: I don't like the handlers.handlers
    PanelSolution = panel.handlers.handlers.PanelSolution,
    PanelSolutionsDone = panel.handlers.handlers.PanelSolutionsDone,
    statusNotification = status.handlers.statusNotification,
    ["window/showDocument"] = util.show_document,
  }

  -- optional handlers
  local logger_conf = config.logger
  if logger_conf.trace_lsp ~= "off" then
    handlers = vim.tbl_extend("force", handlers, {
      ["$/logTrace"] = logger.handle_lsp_trace,
    })
  end

  if logger_conf.trace_lsp_progress then
    handlers = vim.tbl_extend("force", handlers, {
      ["$/progress"] = logger.handle_lsp_progress,
    })
  end

  if logger_conf.log_lsp_messages then
    handlers = vim.tbl_extend("force", handlers, {
      ["window/logMessage"] = logger.handle_log_lsp_messages,
    })
  end

  return handlers
end

return M
