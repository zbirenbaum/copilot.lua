local u = require("copilot.util")
local logger = require("copilot.logger")
---@alias copilot_status_notification_data { status: ''|'Normal'|'InProgress'|'Warning', message: string }

local M = {
  client_id = nil,
  ---@type copilot_status_notification_data
  data = {
    status = "",
    message = "",
  },
  callback = {},
  handlers = {},
}

M.handlers = {
  ---@param result copilot_status_notification_data
  ---@param ctx { client_id: integer, method: string }
  statusNotification = function(_, result, ctx)
    M.client_id = ctx.client_id
    M.data = result

    for callback in pairs(M.callback) do
      callback(M.data)
    end
  end,
}

---@param handler fun(data: copilot_status_notification_data): nil
function M.register_status_notification_handler(handler)
  M.callback[handler] = true
  handler(M.data)
end

---@param handler fun(data: copilot_status_notification_data): nil
function M.unregister_status_notification_handler(handler)
  M.callback[handler] = nil
end

function M.status()
  local c = require("copilot.client")
  local a = require("copilot.api")
  logger.trace("Status called")
  local lines = "Status:"

  ---@param line string|nil
  local function add_line(line)
    if not line then
      return
    end

    if lines ~= "" then
      lines = lines .. "\n" .. line
    else
      lines = line
    end
  end

  ---@param last_line string|nil
  local function flush_lines(last_line)
    add_line(last_line)

    if c.startup_error then
      add_line(c.startup_error)
    end

    logger.notify(lines)
  end

  if c.is_disabled() then
    flush_lines("Offline")
    return
  end

  local client = c.get()
  if not client then
    flush_lines("Not Started")
    return
  end

  add_line("Online")

  coroutine.wrap(function()
    local cserr, status = a.check_status(client)
    if cserr then
      flush_lines(cserr)
      return
    end

    if not status.user then
      flush_lines("Not authenticated. Run ':Copilot auth'")
      return
    elseif status.status == "NoTelemetryConsent" then
      flush_lines("Telemetry terms not accepted")
      return
    elseif status.status == "NotAuthorized" then
      flush_lines("Not authorized")
      return
    end

    local should_attach, no_attach_reason = u.should_attach()
    local is_attached = c.buf_is_attached()
    if is_attached then
      if not should_attach then
        add_line("Enabled manually (" .. no_attach_reason .. ")")
      elseif vim.bo.filetype and vim.bo.filetype ~= "" then
        add_line("Enabled for " .. vim.bo.filetype)
      else
        add_line("Enabled")
      end
    elseif not is_attached then
      if should_attach then
        if vim.bo.filetype and vim.bo.filetype ~= "" then
          add_line("Disabled manually for " .. vim.bo.filetype)
        else
          add_line("Disabled manually")
        end
      else
        add_line("Disabled (" .. no_attach_reason .. ")")
      end
    end

    if string.lower(M.data.status) == "error" then
      add_line(M.data.message)
    end

    flush_lines()
  end)()
end

return M
