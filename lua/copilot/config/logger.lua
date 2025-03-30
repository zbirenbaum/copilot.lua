---@class LoggerConfig
---@field file string Path to the log file
---@field file_log_level integer Log level for the log file, matches vim.log.levels
---@field print_log_level integer Log level for printing to the console, matches vim.log.levels
---@field trace_lsp string Trace level for LSP messages, current does not seem to do anything
---@field trace_lsp_progress boolean Whether to show LSP progress messages
---@field log_lsp_messages boolean Whether to log LSP messages

local logger = {
  ---@type LoggerConfig
  default = {
    file = vim.fn.stdpath("log") .. "/copilot-lua.log",
    file_log_level = vim.log.levels.OFF,
    print_log_level = vim.log.levels.WARN,
    trace_lsp = "off",
    trace_lsp_progress = false,
    log_lsp_messages = false,
  },
}

return logger
