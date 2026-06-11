local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_health")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = child.stop,
  },
})

T["health()"] = MiniTest.new_set()

T["health()"]["check runs without error when client is running"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

T["health()"]["check runs without error when client is not started"] = function()
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

T["health()"]["reports auth.db as local credentials location"] = function()
  child.configure_copilot()
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "auth%.db")
end

T["health()"]["reports LSP authentication status without requiring a buffer attach"] = function()
  child.configure_copilot()
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "authentication status: authenticated as `someUser`")
end

T["health()"]["check runs without error when client is disabled"] = function()
  child.lua([[
    local lsp = require("copilot.lsp")
    lsp.setup = function(_, _) return false end
  ]])
  child.lua([[
    M.setup({ filetypes = { ["*"] = true } })
  ]])
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

return T
