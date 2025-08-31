local reference_screenshot = MiniTest.expect.reference_screenshot
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_util")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
      child.bo.readonly = false
    end,
    post_once = child.stop,
  },
})

T["util()"] = MiniTest.new_set()

T["util()"]["passthrough Esc passes original keymap"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })]])

  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

return T
