local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_base_to_organize")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.run_pre_case()
      child.lua([[s = require('copilot.status')]])
      child.lua([[a = require('copilot.api')]])
    end,
    post_once = child.stop,
  },
})

T["lua()"] = MiniTest.new_set()

T["lua()"]["setup not called, copilot.setup_done is false"] = function()
  eq(child.lua("return M.setup_done"), false)
end

T["lua()"]["setup called, copilot.setup_done is true"] = function()
  child.configure_copilot()
  eq(child.lua("return M.setup_done"), true)
end

T["lua()"]["api.status reroutes to status"] = function()
  child.configure_copilot()
  child.lua("s.data.status = 'test'")
  local status = child.lua("return a.status.data.status")
  eq(status, "test")
end

return T
