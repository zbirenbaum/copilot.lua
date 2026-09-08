local M = {
  calls = {},
  pending = {},
  responses = {},
  options = {},
  killed = 0,
}
local active_restore

function M.reset()
  if active_restore then
    active_restore()
  end
  M.calls = {}
  M.pending = {}
  M.responses = {}
  M.options = {}
  M.killed = 0
  M.on_complete = nil
end

function M.restore()
  if active_restore then
    active_restore()
  end
end

function M.start()
  M.reset()
  local original = vim.system
  local restored = false
  local restore
  restore = function()
    if restored then
      return
    end
    restored = true
    vim.system = original
    if active_restore == restore then
      active_restore = nil
    end
  end
  active_restore = restore
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.system = function(command, options, callback)
    if command[1] == "getconf" then
      return {
        wait = function()
          return { code = 0, stdout = "glibc 2.39", stderr = "" }
        end,
      }
    end
    if command[1] == "ldd" then
      return {
        wait = function()
          return { code = 0, stdout = "ldd (GNU libc) 2.39", stderr = "" }
        end,
      }
    end
    table.insert(M.calls, command)
    table.insert(M.options, options)
    local response = table.remove(M.responses[command[1]] or {}, 1)
    if response == false then
      error(command[1] .. " unavailable")
    end
    local process = {}
    function process.kill()
      M.killed = M.killed + 1
    end
    function process.wait()
      return { code = 0, stdout = "", stderr = "" }
    end
    table.insert(M.pending, { process = process, callback = callback, command = command, response = response })
    return process
  end
  return restore
end

function M.complete_next(result)
  local pending = table.remove(M.pending, 1)
  assert(pending, "no pending process")
  if M.on_complete then
    M.on_complete(pending.command, result or pending.response or { code = 0, stdout = "", stderr = "" })
  end
  pending.callback(result or pending.response or { code = 0, stdout = "", stderr = "" })
end

return M
