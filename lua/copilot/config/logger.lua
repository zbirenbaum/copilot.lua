---@class (exact) LoggerConfig
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

local function validate_log_level(level)
  return type(level) == "number"
    and (
      level == vim.log.levels.OFF
      or level == vim.log.levels.ERROR
      or level == vim.log.levels.WARN
      or level == vim.log.levels.INFO
      or level == vim.log.levels.DEBUG
      or level == vim.log.levels.TRACE
    )
end

---@param config LoggerConfig
function logger.validate(config)
  vim.validate("file", config.file, "string")
  config.file = vim.fs.normalize(config.file)

  vim.validate("file_log_level", config.file_log_level, validate_log_level, false, "any of the vim.log.levels")
  vim.validate("print_log_level", config.print_log_level, validate_log_level, false, "any of the vim.log.levels")
  vim.validate("trace_lsp", config.trace_lsp, function(level)
    return level == "off" or level == "verbose" or level == "debug"
  end, false, "off, verbose or debug")
  vim.validate("trace_lsp_progress", config.trace_lsp_progress, "boolean")
  vim.validate("log_lsp_messages", config.log_lsp_messages, "boolean")
end

return logger
