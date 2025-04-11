local uv = vim.uv

---@class logger
local M = {
  log_file = vim.fn.stdpath("log") .. "/copilot-lua.log",
  file_log_level = vim.log.levels.OFF,
  print_log_level = vim.log.levels.WARN,
  logger_id = 0,
}

local log_level_names = {
  [vim.log.levels.ERROR] = "ERROR", --4
  [vim.log.levels.WARN] = "WARN", --3
  [vim.log.levels.INFO] = "INFO", --2
  [vim.log.levels.DEBUG] = "DEBUG", --1
  [vim.log.levels.TRACE] = "TRACE", --0
}

---@return string timestamp
local function get_timestamp_with_ms()
  local seconds = os.time()
  local milliseconds = math.floor((os.clock() % 1) * 1000)
  return string.format("%s.%03d", os.date("%Y-%m-%d %H:%M:%S", seconds), milliseconds)
end

---@param log_level integer --vim.log.levels
---@param msg string
---@param ... any
---@return string log_msg
local function format_log(log_level, msg, ...)
  local log_level_name = log_level_names[log_level]
  M.logger_id = M.logger_id + 1

  if M.logger_id > 1000000 then
    M.logger_id = 1
  end

  -- we add an id as this process is asynchronous and the logs end up in a different order
  local log_msg = string.format("%s [%d] [%s]: %s", get_timestamp_with_ms(), M.logger_id, log_level_name, msg)

  local args = { ... }
  for _, v in ipairs(args) do
    log_msg = string.format("%s\n%s", log_msg, vim.inspect(v))
  end

  return log_msg
end

---@param msg string
---@param ... any
---@return string log_msg
local function format_notify(msg, ...)
  -- we add an id as this process is asynchronous and the logs end up in a different order
  local log_msg = string.format("[Copilot.lua] %s", msg)

  local args = { ... }
  for _, v in ipairs(args) do
    log_msg = string.format("%s\n%s", log_msg, vim.inspect(v))
  end

  return log_msg
end

---@param log_level integer -- one of the vim.log.levels
---@param msg string
---@param ... any
local function notify_log(log_level, msg, ...)
  local log_msg = format_notify(msg, ...)

  if vim.in_fast_event then
    vim.schedule(function()
      vim.notify(log_msg, log_level)
    end)
  else
    vim.notify(log_msg, log_level)
  end
end

---@param log_level integer -- one of the vim.log.levels
---@param log_file string
---@param msg string
---@param ... any
local function write_log(log_level, log_file, msg, ...)
  local log_msg = format_log(log_level, msg, ...) .. "\n"

  uv.fs_open(log_file, "a", tonumber("644", 8), function(err, fd)
    if err then
      notify_log(vim.log.levels.ERROR, "Failed to open log file: " .. err)
      return
    end

    uv.fs_write(fd, log_msg, -1, function(write_err)
      if write_err then
        notify_log(vim.log.levels.ERROR, "Failed to write to log file: " .. write_err)
      end

      uv.fs_close(fd)
    end)
  end)
end

---@param log_level integer -- one of the vim.log.levels
---@param msg string
---@param ... any
function M.log(log_level, msg, ...)
  if M.file_log_level <= log_level then
    write_log(log_level, M.log_file, msg, ...)
  end

  if M.print_log_level <= log_level then
    notify_log(log_level, msg, ...)
  end
end

---@param msg string
---@param ... any
function M.debug(msg, ...)
  M.log(vim.log.levels.DEBUG, msg, ...)
end

---@param msg string
---@param ... any
function M.trace(msg, ...)
  M.log(vim.log.levels.TRACE, msg, ...)
end

---@param msg string
---@param ... any
function M.error(msg, ...)
  M.log(vim.log.levels.ERROR, msg, ...)
end

---@param msg string
---@param ... any
function M.warn(msg, ...)
  M.log(vim.log.levels.WARN, msg, ...)
end

---@param msg string
---@param ... any
function M.info(msg, ...)
  M.log(vim.log.levels.INFO, msg, ...)
end

---@param msg string
---@param ... any
function M.notify(msg, ...)
  notify_log(vim.log.levels.INFO, msg, ...)
end

---@param conf LoggerConfig
function M.setup(conf)
  M.log_file = conf.file
  M.file_log_level = conf.file_log_level
  M.print_log_level = conf.print_log_level
end

function M.handle_lsp_trace(_, result, _)
  if not result then
    return
  end

  M.trace(string.format("LSP trace - %s", result.message), result.verbose)
end

function M.handle_lsp_progress(_, result, _)
  if not result then
    return
  end

  M.trace(string.format("LSP progress - token %s", result.token), result.value)
end

function M.handle_log_lsp_messages(_, result, _)
  if not result then
    return
  end

  local message = string.format("LSP message: %s", result.message)
  local message_type = result.type --[[@as integer]]

  if message_type == 1 then
    M.error(message)
  elseif message_type == 2 then
    M.warn(message)
  elseif message_type == 3 then
    M.info(message)
  elseif message_type == 4 then
    M.info(message)
  elseif message_type == 5 then
    M.debug(message)
  else
    M.trace(message)
  end
end

return M
