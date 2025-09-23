local reference_screenshot = MiniTest.expect.reference_screenshot
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_keymaps")

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

T["keymaps()"] = MiniTest.new_set()

T["keymaps()"]["passthrough Esc - base test setting highlight"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })]])
  child.lua([[
    require("copilot.keymaps").register_keymap_with_passthrough("n", "<Esc>", function()
      return true
    end, "Passthrough Esc", vim.api.nvim_get_current_buf())
  ]])
  child.type_keys("i123", "<Esc>", "o456", "<Esc>")
  child.type_keys("/123", "<CR>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["keymaps()"]["passthrough Esc with func - return false, will remove hl"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua(
    [[vim.keymap.set("n", "<Esc>", function() vim.cmd.nohlsearch() end, { desc = "general clear highlights" })]]
  )
  child.lua([[
    require("copilot.keymaps").register_keymap_with_passthrough("n", "<esc>", function()
      return false
    end, "Passthrough Esc", vim.api.nvim_get_current_buf())
  ]])
  child.type_keys("i123", "<Esc>", "o456", "<Esc>")
  child.type_keys("/123", "<CR>")
  child.type_keys("<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["keymaps()"]["passthrough Esc - return false, will remove hl"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })]])
  child.lua([[
    require("copilot.keymaps").register_keymap_with_passthrough("n", "<esc>", function()
      return false
    end, "Passthrough Esc", vim.api.nvim_get_current_buf())
  ]])
  child.type_keys("i123", "<Esc>", "o456", "<Esc>")
  child.type_keys("/123", "<CR>")
  child.type_keys("<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["keymaps()"]["passthrough Esc - return true, will not remove hl"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })]])
  child.lua([[
    require("copilot.keymaps").register_keymap_with_passthrough("n", "<Esc>", function()
      return true
    end, "Passthrough Esc", vim.api.nvim_get_current_buf())
  ]])
  child.type_keys("i123", "<Esc>", "o456", "<Esc>")
  child.type_keys("/123", "<CR>")
  child.type_keys("<Esc>")

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

return T
