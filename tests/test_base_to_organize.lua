local eq = MiniTest.expect.equality
-- local neq = MiniTest.expect.no_equality
-- local u = require("tests.utils")
local expect_error = MiniTest.expect.error
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      -- Restart child process with custom 'init.lua' script
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.lua([[M = require('copilot')]])

      child.lua([[c = require('copilot.command')]])
      -- child.lua([[c.enable()]])
      -- child.lua([[c.attach({ force = true })]])
      -- child.lua([[conf = require('copilot.config')]])
      child.lua([[s = require('copilot.status')]])
    end,
    -- Stop once all test cases are finished
    post_once = child.stop,
  },
})

local function run_setup()
  child.lua([[M.setup({
    logger = {
      file_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_example.log",
    },
  })]])
end

T["lua()"] = MiniTest.new_set()

T["lua()"]["setup not called, copilot.setup_done is false"] = function()
  eq(child.lua("return M.setup_done"), false)
end

T["lua()"]["setup called, copilot.setup_done is true"] = function()
  run_setup()
  eq(child.lua("return M.setup_done"), true)
end

T["lua()"]["Copilot status, not initialized, returns error"] = function()
  run_setup()
  expect_error(function()
    child.cmd(":Copilot status")
  end, ".*not initialized.*")
end

return T
