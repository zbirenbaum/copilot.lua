local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_model")
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

T["model()"] = MiniTest.new_set()

-- get_current_model tests

T["model()"]["get_current_model returns empty string by default"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local model = require("copilot.model")
    return model.get_current_model()
  ]])
  eq(result, "")
end

T["model()"]["get_current_model returns config value when set"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local config = require("copilot.config")
    config.copilot_model = "gpt-4o"
    local model = require("copilot.model")
    return model.get_current_model()
  ]])
  eq(result, "gpt-4o")
end

T["model()"]["get_current_model selected_model takes priority over config"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local config = require("copilot.config")
    config.copilot_model = "gpt-4o"
    local model = require("copilot.model")
    model.selected_model = "gpt-4o-mini"
    return model.get_current_model()
  ]])
  eq(result, "gpt-4o-mini")
end

-- set tests

T["model()"]["set with valid model_id notifies"] = function()
  child.configure_copilot()
  child.lua([[
    local model = require("copilot.model")
    model.set({ args = "gpt-4o-mini" })
  ]])

  local messages = child.lua([[
    vim.wait(200, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "Copilot model set to: gpt%-4o%-mini")
end

T["model()"]["set with empty args shows Usage"] = function()
  child.configure_copilot()
  child.lua([[
    local model = require("copilot.model")
    model.set({})
  ]])

  local messages = child.lua([[
    vim.wait(200, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "Usage:")
end

-- get tests

T["model()"]["get shows server default message when no model configured"] = function()
  child.configure_copilot()
  child.lua([[
    local model = require("copilot.model")
    model.get()
  ]])

  local messages = child.lua([[
    vim.wait(200, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "No model configured %(using server default%)")
end

T["model()"]["get shows current model message when model set"] = function()
  child.configure_copilot()
  child.lua([[
    local model = require("copilot.model")
    model.selected_model = "gpt-4o"
    model.get()
  ]])

  local messages = child.lua([[
    vim.wait(200, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "Current model: gpt%-4o")
end

-- list tests

T["model()"]["list shows completion model names"] = function()
  child.configure_copilot()
  child.lua([[
    local model = require("copilot.model")
    model.list()
  ]])

  local messages = child.lua([[
    vim.wait(500, function() return false end, 10)
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])
  u.expect_match(messages, "Available completion models:")
  u.expect_match(messages, "GPT 4o")
  u.expect_match(messages, "GPT 4o Mini")
end

return T
