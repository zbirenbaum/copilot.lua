local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case()
      child.bo.readonly = false
      child.lua("p = require('copilot.panel')")
    end,
    post_once = child.stop,
  },
})

T["panel()"] = MiniTest.new_set()

T["panel()"]["panel suggestions works"] = function()
  child.o.lines, child.o.columns = 30, 100
  child.config.panel = child.config.panel .. "auto_refresh = true,"
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.lua("p.toggle()")

  local lines = child.lua([[
    local messages = ""
    local function suggestion_is_visible()
      lines = vim.api.nvim_buf_get_lines(2, 4, 5, false)
      return lines[1] == "789" or lines[1] == "789\r"
    end

    vim.wait(30000, function()
      return suggestion_is_visible()
    end, 50)

    return lines
  ]])

  -- For Windows, on some shells not all
  if lines[1] == "789\r" then
    lines[1] = "789"
  end

  eq(lines[1], "789")
end

return T
