local u = require("copilot.suggestion.utils")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function() end,
  },
})

T["suggestion_utils()"] = MiniTest.new_set()

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
