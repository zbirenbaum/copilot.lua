local reference_screenshot = MiniTest.expect.reference_screenshot
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_suggestion")

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

T["suggestion()"] = MiniTest.new_set()

T["suggestion()"]["suggestion works"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot())
end

T["suggestion()"]["auto_trigger is false, will not show ghost test"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  vim.loop.sleep(3000)
  child.lua("vim.wait(0)")

  reference_screenshot(child.get_screenshot())
end

T["suggestion()"]["accept keymap to trigger sugestion"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion .. "keymap = { accept = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot())
end

T["suggestion()"]["accept keymap, no suggestion, execute normal keystroke"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion
    .. "keymap = { accept = '<Tab>' },\n"
    .. "trigger_on_accept = false,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")

  reference_screenshot(child.get_screenshot())
end

return T
