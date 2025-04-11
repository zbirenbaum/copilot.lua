local M = {
  expect_match = MiniTest.new_expectation(
    -- Expectation subject
    "string matching",
    -- Predicate
    ---@param str     string|number
    ---@param pattern string|number
    function(str, pattern)
      return str:find(pattern) ~= nil
    end,
    -- Fail context
    ---@param str     string|number
    ---@param pattern string|number
    function(str, pattern)
      return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
    end
  ),
  expect_no_match = MiniTest.new_expectation(
    -- Expectation subject
    "no string matching",
    -- Predicate
    ---@param str     string|number
    ---@param pattern string|number
    function(str, pattern)
      return str:find(pattern) == nil
    end,
    -- Fail context
    ---@param str     string|number
    ---@param pattern string|number
    function(str, pattern)
      return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
    end
  ),
  expect_not_empty = MiniTest.new_expectation(
    -- Expectation subject
    "not empty",
    -- Predicate
    ---@param val any|nil
    function(val)
      if val == nil or val == vim.NIL then
        return false
      end

      if type(val) == "string" then
        return val ~= ""
      elseif type(val) == "table" then
        return val ~= {}
      end

      return true
    end,
    -- Fail context
    ---@param _ any|nil
    function(_)
      return "Expected value to be not empty"
    end
  ),
  expect_empty = MiniTest.new_expectation(
    -- Expectation subject
    "empty",
    -- Predicate
    ---@param val any|nil
    function(val)
      if val == nil or val == vim.NIL then
        return true
      end

      if type(val) == "string" then
        return val == ""
      elseif type(val) == "table" then
        return val == {}
      end

      return false
    end,
    -- Fail context
    ---@param val any|nil
    function(val)
      return "Expected value to be empty\nObserved value: " .. vim.inspect(val)
    end
  ),
  set_lines = function(child, lines)
    child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  end,
  get_lines = function(child)
    return child.api.nvim_buf_get_lines(0, 0, -1, true)
  end,
}

return M
