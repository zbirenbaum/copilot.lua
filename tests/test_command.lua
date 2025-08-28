local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_suggestion")
local u = require("tests.utils")
local reference_screenshot = MiniTest.expect.reference_screenshot

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case()
      child.bo.readonly = false
    end,
    post_once = child.stop,
  },
})

T["command()"] = MiniTest.new_set()

T["command()"]["version works"] = function()
  child.configure_copilot()
  child.cmd("Copilot version")
  local result = child.cmd_capture("mess")
  u.expect_match(result, ".*copilot language server.*copilot%.lua.*Node%.js.*language%-server%.js.*")
end

T["command()"]["panel toggle - open works"] = function()
  child.configure_copilot()
  child.cmd("Copilot panel toggle")
  reference_screenshot(child.get_screenshot())
end

T["command()"]["panel toggle - close works"] = function()
  child.configure_copilot()
  child.cmd("Copilot panel toggle")
  child.cmd("Copilot panel toggle")
  reference_screenshot(child.get_screenshot())
end

T["command()"]["panel open - it works"] = function()
  child.configure_copilot()
  child.cmd("Copilot panel open")
  reference_screenshot(child.get_screenshot())
end

T["command()"]["panel close - it works"] = function()
  child.configure_copilot()
  child.cmd("Copilot panel open")
  child.cmd("Copilot panel close")
  reference_screenshot(child.get_screenshot())
end

T["command()"]["panel is_open - is opened - returns true"] = function()
  child.configure_copilot()
  child.cmd("Copilot panel open")
  local is_open = child.cmd_capture("Copilot panel is_open")
  u.expect_match(is_open, "true")
end

T["command()"]["panel is_open - is closed - returns false"] = function()
  child.configure_copilot()
  local is_open = child.cmd_capture("Copilot panel is_open")
  u.expect_match(is_open, "false")
end

return T
