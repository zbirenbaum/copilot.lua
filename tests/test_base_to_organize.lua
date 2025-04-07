local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
-- local env = require("tests.env")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.lua([[M = require('copilot')]])
      child.lua([[c = require('copilot.command')]])
      child.lua([[s = require('copilot.status')]])
      -- child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
    end,
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

return T
