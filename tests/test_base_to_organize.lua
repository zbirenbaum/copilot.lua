local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local env = require("tests.env")
local utils_debug = require("tests.utils_debug")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.lua([[M = require('copilot')]])
      child.lua([[c = require('copilot.command')]])
      child.lua([[s = require('copilot.status')]])
      child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
      utils_debug.launch_lua_debugee(child)
    end,
    post_once = child.stop,
  },
})

-- TODO: find a way for autocmd or something
local function run_setup()
  -- utils_debug.attach_to_debugee()
  vim.loop.sleep(10000)
  -- vim.wait(0)
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
