local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_api")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
      child.configure_copilot()
    end,
    post_once = child.stop,
  },
})

T["api()"] = MiniTest.new_set()

-- check_status tests

T["api()"]["check_status coroutine mode returns user and status"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local data
    coroutine.wrap(function()
      local err, d = api.check_status(c)
      data = d
    end)()
    vim.wait(500, function() return data ~= nil end, 10)
    return data
  ]])
  eq(result.user, "someUser")
  eq(result.status, "OK")
end

T["api()"]["check_status callback mode returns user and status"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local cb_data
    api.check_status(c, {}, function(err, data, ctx)
      cb_data = data
    end)
    vim.wait(500, function() return cb_data ~= nil end, 10)
    return cb_data
  ]])
  eq(result.user, "someUser")
  eq(result.status, "OK")
end

-- get_version test

T["api()"]["get_version returns version string"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local data
    coroutine.wrap(function()
      local err, d = api.get_version(c)
      data = d
    end)()
    vim.wait(500, function() return data ~= nil end, 10)
    return data
  ]])
  eq(result.version, "1.430.0")
end

-- get_models test

T["api()"]["get_models returns 3 models"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local data
    coroutine.wrap(function()
      local err, d = api.get_models(c)
      data = d
    end)()
    vim.wait(500, function() return data ~= nil end, 10)
    return data
  ]])
  eq(#result, 3)
  eq(result[1].id, "gpt-4o")
  eq(result[2].id, "gpt-4o-mini")
  eq(result[3].id, "claude-sonnet")
end

-- notify test

T["api()"]["notify does not error"] = function()
  -- api.notify calls client:notify which may return nil for mocked servers
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local ok, err = pcall(function()
      api.notify(c, "$/setTrace", { value = "off" })
    end)
    return ok
  ]])
  eq(result, true)
end

-- notify_accepted test

T["api()"]["notify_accepted does not error"] = function()
  -- notifyAccepted handler is synchronous in the stub, so the coroutine
  -- resumes immediately. We use callback mode to avoid coroutine timing issues.
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local finished = false
    api.notify_accepted(c, { uuid = "test-uuid" }, function(err, data, ctx)
      finished = true
    end)
    vim.wait(500, function() return finished end, 10)
    return finished
  ]])
  eq(result, true)
end

-- notify_rejected test

T["api()"]["notify_rejected does not error"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local finished = false
    api.notify_rejected(c, { uuids = {"test-uuid"} }, function(err, data, ctx)
      finished = true
    end)
    vim.wait(500, function() return finished end, 10)
    return finished
  ]])
  eq(result, true)
end

-- sign_in_initiate test

T["api()"]["sign_in_initiate returns userCode"] = function()
  local result = child.lua([[
    local api = require("copilot.api")
    local client = require("copilot.client")
    local c = client.get()
    local data
    coroutine.wrap(function()
      local err, d = api.sign_in_initiate(c)
      data = d
    end)()
    vim.wait(500, function() return data ~= nil end, 10)
    return data
  ]])
  eq(result.userCode, "ABCD-1234")
  u.expect_match(result.verificationUri, "github.com")
end

return T
