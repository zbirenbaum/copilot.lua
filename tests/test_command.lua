local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_suggestion")
local u = require("tests.utils")

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

return T
