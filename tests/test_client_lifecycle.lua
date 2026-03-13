local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client_lifecycle")
local u = require("tests.utils")
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

  -- Store original client id
  local original_id = child.lua("return c.id")

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
    vim.wait(200, function() return false end, 10)
    require("copilot.command").enable()
  ]])

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
