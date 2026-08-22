local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client_lifecycle")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
      child.lua("c = require('copilot.client')")
    end,
    post_once = child.stop,
  },
})

T["client lifecycle()"] = MiniTest.new_set()

T["client lifecycle()"]["defers start until LSP readiness"] = function()
  local result = child.lua([[
    local lsp = require("copilot.lsp")
    local ready
    local starts = 0
    local original_start = vim.lsp.start
    lsp.setup = function(_, _, callback)
      ready = callback
    end
    vim.lsp.start = function(...)
      starts = starts + 1
      return original_start(...)
    end
    c.setup()
    local before = starts
    ready(nil)
    vim.wait(200, function()
      return starts > before
    end, 10)
    vim.lsp.start = original_start
    return { before = before, after = starts, attached = c.buf_is_attached(0) }
  ]])
  eq(result.before, 0)
  eq(result.after, 1)
  eq(result.attached, true)
end

T["client lifecycle()"]["attach requests are silent while LSP readiness is pending"] = function()
  local result = child.lua([[
    local lsp = require("copilot.lsp")
    local ready
    local notifications = {}
    local original_notify = vim.notify
    lsp.setup = function(_, _, callback)
      ready = callback
    end
    vim.notify = function(message)
      table.insert(notifications, message)
    end
    c.setup()
    c.buf_attach(true, 0)
    vim.wait(100, function() return false end, 10)
    local pending_notifications = vim.deepcopy(notifications)
    ready(nil)
    vim.wait(200, function() return c.buf_is_attached(0) end, 10)
    vim.notify = original_notify
    return { notifications = pending_notifications, attached = c.buf_is_attached(0) }
  ]])
  eq(result.notifications, {})
  eq(result.attached, true)
end

T["client lifecycle()"]["attach requests report missing configuration outside setup"] = function()
  local result = child.lua([[
    local notifications = {}
    local original_notify = vim.notify
    vim.notify = function(message)
      table.insert(notifications, message)
    end
    c.buf_attach(true, 0)
    vim.wait(100, function() return #notifications > 0 end, 10)
    vim.notify = original_notify
    return notifications
  ]])
  eq(result, { "[Copilot.lua] cannot attach: configuration not initialized" })
end

T["client lifecycle()"]["only newest readiness completion starts client"] = function()
  local result = child.lua([[
    local lsp = require("copilot.lsp")
    local callbacks = {}
    local starts = 0
    local original_start = vim.lsp.start
    lsp.setup = function(_, _, callback)
      table.insert(callbacks, callback)
    end
    vim.lsp.start = function(...)
      starts = starts + 1
      return original_start(...)
    end
    c.setup()
    c.setup()
    callbacks[2](nil)
    callbacks[1](nil)
    vim.wait(200, function()
      return starts > 0
    end, 10)
    vim.lsp.start = original_start
    return starts
  ]])
  eq(result, 1)
end

T["client lifecycle()"]["teardown during install prevents startup"] = function()
  local result = child.lua([[
    local lsp = require("copilot.lsp")
    local ready
    local starts = 0
    local original_start = vim.lsp.start
    lsp.setup = function(_, _, callback)
      ready = callback
    end
    vim.lsp.start = function(...)
      starts = starts + 1
      return original_start(...)
    end
    c.setup()
    c.teardown()
    ready(nil)
    vim.wait(100, function() return false end, 10)
    vim.lsp.start = original_start
    return starts
  ]])
  eq(result, 0)
end

T["client lifecycle()"]["readiness errors can be retried"] = function()
  local result = child.lua([[
    local lsp = require("copilot.lsp")
    local callbacks = {}
    lsp.setup = function(_, _, callback)
      table.insert(callbacks, callback)
    end
    c.setup()
    callbacks[1]("install failed")
    local first_error = c.startup_error
    local disabled_after_error = c.is_disabled()
    c.setup()
    callbacks[2](nil)
    vim.wait(200, function()
      return c.id ~= nil
    end, 10)
    return { first_error = first_error, disabled_after_error = disabled_after_error, retry = c.id ~= nil }
  ]])
  eq(result.first_error, "install failed")
  eq(result.disabled_after_error, true)
  eq(result.retry, true)
end

-- Fix #1: ensure_client_started should have a startup guard to prevent duplicate spawns
T["client lifecycle()"]["ensure_client_started sets starting guard during startup"] = function()
  child.configure_copilot()

  -- After initialization, client_starting should be false (startup completed)
  local client_starting = child.lua("return c.client_starting")
  eq(client_starting, false)
end

T["client lifecycle()"]["ensure_client_started with starting guard prevents duplicate calls"] = function()
  child.configure_copilot()

  -- Simulate the guard being set (as if startup is in progress)
  child.lua("c.client_starting = true")

  -- Try to start another client - should be blocked by the guard
  child.lua([[
    c.id = nil
    c.ensure_client_started()
  ]])

  -- id should still be nil because the guard prevented a new start
  local new_id = child.lua("return c.id")
  eq(new_id, vim.NIL)
end

-- Fix #2: setup() should stop existing client before resetting M.id
T["client lifecycle()"]["setup stops existing client before resetting id"] = function()
  child.configure_copilot()

  -- Verify client is running
  local id_before = child.lua("return c.id")
  assert(id_before ~= vim.NIL, "client should be running")

  -- Track whether the old client was stopped
  child.lua([[
    _G.old_client_stopped = false
    local old_client = vim.lsp.get_client_by_id(c.id)
    if old_client then
      local original_stop = old_client.stop
      old_client.stop = function(self, ...)
        _G.old_client_stopped = true
        return original_stop(self, ...)
      end
    end
  ]])

  -- Call setup again (simulates :Copilot disable then :Copilot enable)
  child.lua("c.setup()")
  child.lua("vim.wait(500, function() return false end, 10)")

  -- The old client should have been stopped
  local was_stopped = child.lua("return _G.old_client_stopped")
  eq(was_stopped, true)
end

-- Fix #3: VimLeavePre should clean up the LSP client
T["client lifecycle()"]["setup registers VimLeavePre autocmd"] = function()
  child.configure_copilot()

  local has_autocmd = child.lua([[
    local autocmds = vim.api.nvim_get_autocmds({
      group = "copilot.client",
      event = "VimLeavePre",
    })
    return #autocmds > 0
  ]])

  eq(has_autocmd, true)
end

T["client lifecycle()"]["VimLeavePre stops the LSP client"] = function()
  child.configure_copilot()

  -- Verify client is running
  local id = child.lua("return c.id")
  assert(id ~= vim.NIL, "client should be running")

  -- Track whether stop was called
  child.lua([[
    _G.client_stopped_on_leave = false
    local client_obj = vim.lsp.get_client_by_id(c.id)
    if client_obj then
      local original_stop = client_obj.stop
      client_obj.stop = function(self, ...)
        _G.client_stopped_on_leave = true
        return original_stop(self, ...)
      end
    end
  ]])

  -- Trigger VimLeavePre
  child.lua([[
    vim.api.nvim_exec_autocmds("VimLeavePre", { group = "copilot.client" })
    vim.wait(200, function() return false end, 10)
  ]])

  local was_stopped = child.lua("return _G.client_stopped_on_leave")
  eq(was_stopped, true)
end

-- Regression: disable/enable cycle should not leak processes
T["client lifecycle()"]["disable then enable does not leak client processes"] = function()
  child.configure_copilot()

  local id_before = child.lua("return c.id")
  assert(id_before ~= vim.NIL, "client should be running")

  -- Disable and re-enable
  child.lua([[
    require("copilot.command").disable()
    _G.initialized_after_disable = require("copilot.client").initialized
    require("copilot.command").enable()
  ]])

  eq(child.lua("return _G.initialized_after_disable"), false)

  -- Wait for the new client to initialize
  child.lua([[
    vim.wait(2000, function()
      return require("copilot.client").initialized
    end, 10)
  ]])

  -- There should be exactly 1 active (non-stopped) copilot LSP client
  local client_count = child.lua([[
    local count = 0
    for _, cl in ipairs(vim.lsp.get_clients({ name = "copilot" })) do
      if not cl:is_stopped() then
        count = count + 1
      end
    end
    return count
  ]])

  eq(client_count, 1)
end

return T
