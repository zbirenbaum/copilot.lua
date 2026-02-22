local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_highlight")

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

T["highlight()"] = MiniTest.new_set()

T["highlight()"]["CopilotSuggestion highlight group exists after setup"] = function()
  child.lua("vim.wait(100, function() return false end, 10)")
  local result = child.lua([[
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "CopilotSuggestion" })
    return ok and not vim.tbl_isempty(hl)
  ]])
  eq(result, true)
end

T["highlight()"]["CopilotAnnotation highlight group exists after setup"] = function()
  child.lua("vim.wait(100, function() return false end, 10)")
  local result = child.lua([[
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "CopilotAnnotation" })
    return ok and not vim.tbl_isempty(hl)
  ]])
  eq(result, true)
end

T["highlight()"]["does not override existing CopilotSuggestion highlight"] = function()
  child.lua([[
    vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#ff0000" })
  ]])
  child.lua([[
    require("copilot.highlight").setup()
    vim.wait(100, function() return false end, 10)
  ]])
  local result = child.lua([[
    local hl = vim.api.nvim_get_hl(0, { name = "CopilotSuggestion" })
    return hl.fg
  ]])
  eq(result, 0xff0000)
end

return T
