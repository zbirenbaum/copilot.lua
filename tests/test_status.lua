local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_status")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = child.stop,
  },
})

T["status()"] = MiniTest.new_set()

-- register handler tests

T["status()"]["register handler called immediately with current data"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local status = require("copilot.status")
    local received = nil
    status.register_status_notification_handler(function(data)
      received = data
    end)
    return received ~= nil
  ]])
  eq(result, true)
end

-- unregister handler tests

T["status()"]["unregister stops callbacks"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local status = require("copilot.status")
    local call_count = 0
    local handler = function(data)
      call_count = call_count + 1
    end
    -- registering calls handler immediately
    status.register_status_notification_handler(handler)
    local count_after_register = call_count

    -- unregister
    status.unregister_status_notification_handler(handler)

    -- simulate a notification - should not increment count
    status.handlers.statusNotification(nil,
      { status = "Normal", message = "" },
      { client_id = 1, method = "statusNotification" })

    return { after_register = count_after_register, final = call_count }
  ]])
  eq(result.after_register, 1)
  eq(result.final, 1) -- should not have been called again
end

-- statusNotification tests

T["status()"]["statusNotification broadcasts to all handlers"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local status = require("copilot.status")
    local handler1_called = false
    local handler2_called = false

    status.register_status_notification_handler(function(data)
      handler1_called = true
    end)
    status.register_status_notification_handler(function(data)
      handler2_called = true
    end)

    -- Reset flags after initial registration calls
    handler1_called = false
    handler2_called = false

    -- Fire notification
    status.handlers.statusNotification(nil,
      { status = "Normal", message = "test" },
      { client_id = 1, method = "statusNotification" })

    return { h1 = handler1_called, h2 = handler2_called }
  ]])
  eq(result.h1, true)
  eq(result.h2, true)
end

T["status()"]["statusNotification updates stored data"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local status = require("copilot.status")
    status.handlers.statusNotification(nil,
      { status = "InProgress", message = "working" },
      { client_id = 42, method = "statusNotification" })
    return { status = status.data.status, message = status.data.message, client_id = status.client_id }
  ]])
  eq(result.status, "InProgress")
  eq(result.message, "working")
  eq(result.client_id, 42)
end

-- status display tests

T["status()"]["status shows Online when running"] = function()
  child.configure_copilot()
  child.lua([[
    local status = require("copilot.status")
    status.status()
  ]])

  local messages = child.lua([[
    local messages = ""
    vim.wait(500, function()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return messages:find("Online")
    end, 50)
    return messages
  ]])
  u.expect_match(messages, "Online")
end

T["status()"]["status shows Offline when disabled"] = function()
  -- Override lsp.setup to return false, simulating disabled state
  child.lua([[
    local lsp = require("copilot.lsp")
    lsp.setup = function(_, _)
      return false
    end
  ]])

  child.lua([[
    M.setup({
      filetypes = { ["*"] = true },
    })
  ]])

  -- Wait for initialization
  child.lua("vim.wait(200, function() return false end, 10)")

  child.lua([[
    local status = require("copilot.status")
    status.status()
  ]])

  local messages = child.lua([[
    vim.wait(200, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "Offline")
end

return T
