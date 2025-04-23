local M = {
  ---@type any
  copilot_timer = nil,
}

local logger = require("copilot.logger")

function M.stop_timer()
  if M.copilot_timer then
    logger.trace("suggestion stop timer")
    vim.fn.timer_stop(M.copilot_timer)
    M.copilot_timer = nil
  end
end

return M
