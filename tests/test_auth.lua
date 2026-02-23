local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_auth")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["auth()"] = MiniTest.new_set()

T["auth()"]["auth before attaching, should not give error"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Authenticated as GitHub user.*") ~= nil
    end

    vim.wait(5000, function()
      return has_passed()
    end, 50)

    return messages 
  ]])

  u.expect_match(messages, ".*Authenticated as GitHub user.*")
end

T["auth()"]["auth issue replication"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")

  child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Authenticated as GitHub user.*") ~= nil
    end

    vim.wait(5000, function()
      return has_passed()
    end, 50)
  ]])

  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Online.*") ~= nil
    end

    vim.wait(5000, function()
      return has_passed()
    end, 50)

    return messages 
  ]])

  u.expect_match(messages, ".*Online.*")
end

T["auth()"]["is_authenticated when not authed returns false"] = function()
  -- Test before client is initialized (no configure_copilot call)
  local result = child.lua([[
    local auth = require("copilot.auth")
    local auth_result = auth.is_authenticated()
    return tostring(auth_result)
  ]])

  u.expect_match(result, "false")
end

T["auth()"]["is_authenticated when authed returns true"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")

  child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Authenticated as GitHub user.*") ~= nil
    end

    vim.wait(5000, function()
      return has_passed()
    end, 50)
  ]])

  local result = child.lua([[
    local auth_result = ""
    local function has_passed()
      auth_result = require("copilot.auth").is_authenticated() or ""
      return auth_result == true
    end

    vim.wait(5000, function()
      return has_passed()
    end, 50)

    return tostring(auth_result)
  ]])

  u.expect_match(result, "true")
end

return T
