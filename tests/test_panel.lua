local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case()
      child.bo.readonly = false
      child.lua("M = require('copilot')")
      child.lua("p = require('copilot.panel')")
    end,
    post_once = child.stop,
  },
})

T["panel()"] = MiniTest.new_set()

-- This test can fail if the LSP is taking more time than usual and re-running it passes
T["panel()"]["panel suggestions works"] = function()
  child.o.lines, child.o.columns = 30, 100
  child.config.panel = child.config.panel .. "auto_refresh = true,"
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.lua("p.toggle()")

  local i = 0
  local lines = ""
  while i < 50 do
    vim.loop.sleep(200)
    child.lua("vim.wait(0)")
    lines = child.api.nvim_buf_get_lines(2, 4, 5, false)
    if lines[1] == "789" then
      break
    end
    i = i + 1
  end

  eq(lines[1], "789")
end

return T
