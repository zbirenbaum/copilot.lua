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

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["auto_trigger is false, will not show ghost test"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  vim.loop.sleep(3000)
  child.lua("vim.wait(0)")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept keymap to trigger sugestion"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion .. "keymap = { accept = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept keymap, no suggestion, execute normal keystroke"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion
    .. "keymap = { accept = '<Tab>' },\n"
    .. "trigger_on_accept = false,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept_word, 1 word, works"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true," .. "keymap = { accept_word = '<C-e>' },"
  child.configure_copilot()
  child.type_keys("i1, 2, 3,", "<Esc>", "o4, 5, 6,", "<Esc>", "o7, ")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept_word, 3 words, works"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true," .. "keymap = { accept_word = '<C-e>' },"
  child.configure_copilot()
  child.type_keys("i1, 2, 3,", "<Esc>", "o4, 5, 6,", "<Esc>", "o7, ")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<C-e>", "<C-e>", "<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

-- - accept_word, 1 word then next
-- - accept_word, 1 word then prev

T["suggestion()"]["accept_word, 1 word, then dismiss"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion
    .. "auto_trigger = true,"
    .. "keymap = { accept_word = '<C-e>', dismiss = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i1, 2, 3,", "<Esc>", "o4, 5, 6,", "<Esc>", "o7, ")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Tab>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept_word, 1 word, then accept"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.config.suggestion = child.config.suggestion
    .. "auto_trigger = true,"
    .. "keymap = { accept_word = '<C-e>', accept = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i1, 2, 3,", "<Esc>", "o4, 5, 6,", "<Esc>", "o7, ")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Tab>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 9, 10 } })
end

T["suggestion()"]["accept_line, 1 line, works"] = function()
  child.o.lines, child.o.columns = 30, 15
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true," .. "keymap = { accept_line = '<C-e>' },"
  child.configure_copilot()
  child.type_keys("i{", "<Esc>o", "  1,2,3", "<Esc>o", "4,5,6", "<Esc>o", "7,8,9", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o", "  10,11,12", "<Esc>", "o13,14,15", "<Esc>", "o16,17,18", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 29, 30 } })
end

T["suggestion()"]["accept_line, 3 lines, works"] = function()
  child.o.lines, child.o.columns = 50, 15
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true," .. "keymap = { accept_line = '<C-e>' },"
  child.configure_copilot()
  child.type_keys("i{", "<Esc>o", "  1,2,3", "<Esc>o", "4,5,6", "<Esc>o", "7,8,9", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o", "  10,11,12", "<Esc>", "o13,14,15", "<Esc>", "o16,17,18", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<C-e>", "<C-e>", "<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 49, 50 } })
end

-- - accept_line, 1 line then next
-- - accept_line, 1 line then prev

T["suggestion()"]["accept_line, 1 line, then dismiss"] = function()
  child.o.lines, child.o.columns = 30, 15
  child.config.suggestion = child.config.suggestion
    .. "auto_trigger = true,"
    .. "keymap = { accept_line = '<C-e>', dismiss = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i{", "<Esc>o", "  1,2,3", "<Esc>o", "4,5,6", "<Esc>o", "7,8,9", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o", "  10,11,12", "<Esc>", "o13,14,15", "<Esc>", "o16,17,18", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Tab>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 29, 30 } })
end

T["suggestion()"]["accept_line, 1 line, then accept"] = function()
  child.o.lines, child.o.columns = 50, 40
  child.config.suggestion = child.config.suggestion
    .. "auto_trigger = true,"
    .. "keymap = { accept_line = '<C-e>', accept = '<Tab>' },"
  child.configure_copilot()
  child.type_keys("i# Numbers in a 3x3 grid, up to 63", "<Esc>")
  child.type_keys("o{", "<Esc>o", "  1,2,3", "<Esc>o", "4,5,6", "<Esc>o", "7,8,9", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o", "  10,11,12", "<Esc>", "o13,14,15", "<Esc>", "o16,17,18", "<Esc>o<bs>", "}", "<Esc>")
  child.type_keys("o{", "<Esc>o")
  child.wait_for_suggestion()
  child.type_keys("<C-e>", "<Tab>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_lines = { 49, 50 } })
end

return T
