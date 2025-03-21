local uv = vim.uv

---@class logger
local mod = {
  log_file = vim.fn.stdpath("log") .. "/copilot-lua.log",
  file_log_level = vim.log.levels.OFF,
  print_log_level = vim.log.levels.WARN,
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
---@param data any
---@return string log_msg
local function format_log(log_level, msg, data)
  local log_level_name = log_level_names[log_level]
  local log_msg = string.format("%s [%s]: %s", get_timestamp_with_ms(), log_level_name, msg)

  if data then
    log_msg = string.format("%s\n%s", log_msg, vim.inspect(data))
  end

  return log_msg
end

---@param log_level integer -- one of the vim.log.levels
---@param msg string
---@param data any
local function notify_log(log_level, msg, data)
  local log_msg = format_log(log_level, msg, data)
  vim.notify(log_msg, log_level)
end

---@param log_level integer -- one of the vim.log.levels
---@param log_file string
---@param msg string
---@param data any
local function write_log(log_level, log_file, msg, data)
  local log_msg = format_log(log_level, msg, data) .. "\n"

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
---@param data any
---@param force_print boolean
function mod.log(log_level, msg, data, force_print)
  if mod.file_log_level <= log_level then
    write_log(log_level, mod.log_file, msg, data)
  end

  if force_print or (mod.print_log_level <= log_level) then
    notify_log(log_level, msg, data)
  end
end

---@param msg string
---@param data any
function mod.debug(msg, data)
  mod.log(vim.log.levels.DEBUG, msg, data, false)
end

---@param msg string
---@param data any
function mod.trace(msg, data)
  mod.log(vim.log.levels.TRACE, msg, data, false)
end

---@param msg string
---@param data any
function mod.error(msg, data)
  mod.log(vim.log.levels.ERROR, msg, data, false)
end

---@param msg string
---@param data any
function mod.warn(msg, data)
  mod.log(vim.log.levels.WARN, msg, data, false)
end

---@param msg string
---@param data any
function mod.info(msg, data)
  mod.log(vim.log.levels.INFO, msg, data, false)
end

---@param msg string
---@param data any
function mod.notify(msg, data)
  mod.log(vim.log.levels.INFO, msg, data, true)
end

---@param conf copilot_config_logging
function mod.setup(conf)
  mod.log_file = conf.file
  mod.file_log_level = conf.file_log_level
  mod.print_log_level = conf.print_log_level
end

function mod.handle_lsp_trace(_, result, _)
  if not result then
    return
  end

  mod.trace(string.format("LSP trace - %s", result.message), result.verbose)
end

function mod.handle_lsp_progress(_, result, _)
  if not result then
    return
  end

  mod.trace(string.format("LSP progress - token %s", result.token), result.value)
end

function mod.handle_log_lsp_messages(_, result, _)
  if not result then
    return
  end

  local message = string.format("LSP message: %s", result.message)
  local message_type = result.type --[[@as integer]]

  if message_type == 1 then
    mod.error(message)
  elseif message_type == 2 then
    mod.warn(message)
  elseif message_type == 3 then
    mod.info(message)
  elseif message_type == 4 then
    mod.info(message)
  elseif message_type == 5 then
    mod.debug(message)
  else
    mod.trace(message)
  end
end

return mod
