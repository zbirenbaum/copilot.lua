local u = require("copilot.suggestion.utils")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function() end,
  },
})

T["suggestion_utils()"] = MiniTest.new_set()

T["suggestion_utils()"]["get_display_adjustments"] = MiniTest.new_set()

T["suggestion_utils()"]["get_display_adjustments"]["basic non-whitespace match"] = function()
  local result, outdent = u.get_display_adjustments("7 8 9", 0, 3, "7 ")
  eq(result, "8 9")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["whitespace matching indent"] = function()
  local result, outdent = u.get_display_adjustments("  if foo:", 0, 3, "  ")
  eq(result, "if foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["whitespace outdent"] = function()
  local result, outdent = u.get_display_adjustments("  if foo:", 0, 5, "    ")
  eq(result, "if foo:")
  eq(outdent, 2)
end

T["suggestion_utils()"]["get_display_adjustments"]["whitespace more indent"] = function()
  local result, outdent = u.get_display_adjustments("    if foo:", 0, 3, "  ")
  eq(result, "  if foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["range start > 0 at boundary"] = function()
  local result, outdent = u.get_display_adjustments("if foo:", 2, 3, "  ")
  eq(result, "if foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["range start > 0 past boundary"] = function()
  local result, outdent = u.get_display_adjustments("if foo:", 2, 4, "  i")
  eq(result, "f foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["empty line"] = function()
  local result, outdent = u.get_display_adjustments("if foo:", 0, 1, "")
  eq(result, "if foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["no match fallback"] = function()
  local result, outdent = u.get_display_adjustments("abc", 0, 4, "xyz")
  eq(result, "")
  eq(outdent, 0)
end

T["suggestion_utils()"]["get_display_adjustments"]["tab whitespace"] = function()
  local result, outdent = u.get_display_adjustments("\tif foo:", 0, 2, "\t")
  eq(result, "if foo:")
  eq(outdent, 0)
end

T["suggestion_utils()"]["remove common suffix"] = function()
  local test_cases = {
    { [[event1 = ("test", ),]], [["test2"),]], [["test2"]] },
    --                    ^
    { [[event2 = ("test", ""),]], [[test2"),]], [[test2]] },
    --                     ^
    { [[event3 = ("test", ]], [["test2"),]], [["test2"),]] },
    --                    ^
    { [[event4 = ("test", ]], "", "" },
    { "", [[("test"),]], [[("test"),]] },
  }

  for _, case in ipairs(test_cases) do
    local str, substr, expected = unpack(case)
    local result = u.remove_common_suffix(str, substr)
    eq(result, expected)
  end
end

return T
