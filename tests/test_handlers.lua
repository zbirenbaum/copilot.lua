local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_handlers")

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

T["handlers()"] = MiniTest.new_set()

T["handlers()"]["get_handlers returns table with required handlers"] = function()
  local result = child.lua([[
    local handlers_mod = require("copilot.client.handlers")
    local handlers = handlers_mod.get_handlers()
    local keys = {}
    for k, _ in pairs(handlers) do
      table.insert(keys, k)
    end
    table.sort(keys)
    return keys
  ]])
  local has_panel_solution = false
  local has_status = false
  for _, key in ipairs(result) do
    if key == "PanelSolution" then
      has_panel_solution = true
    end
    if key == "statusNotification" then
      has_status = true
    end
  end
  eq(has_panel_solution, true)
  eq(has_status, true)
end

T["handlers()"]["trace handler included when trace_lsp is not off"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.logger.trace_lsp = "verbose"
    local handlers_mod = require("copilot.client.handlers")
    local handlers = handlers_mod.get_handlers()
    return handlers["$/logTrace"] ~= nil
  ]])
  eq(result, true)
end

T["handlers()"]["trace handler excluded when trace_lsp is off"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.logger.trace_lsp = "off"
    local handlers_mod = require("copilot.client.handlers")
    local handlers = handlers_mod.get_handlers()
    return handlers["$/logTrace"] ~= nil
  ]])
  eq(result, false)
end

T["handlers()"]["progress handler included when trace_lsp_progress is true"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.logger.trace_lsp_progress = true
    local handlers_mod = require("copilot.client.handlers")
    local handlers = handlers_mod.get_handlers()
    return handlers["$/progress"] ~= nil
  ]])
  eq(result, true)
end

T["handlers()"]["log message handler included when log_lsp_messages is true"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.logger.log_lsp_messages = true
    local handlers_mod = require("copilot.client.handlers")
    local handlers = handlers_mod.get_handlers()
    return handlers["window/logMessage"] ~= nil
  ]])
  eq(result, true)
end

return T
