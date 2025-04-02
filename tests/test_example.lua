local eq = MiniTest.expect.equality
local neq = MiniTest.expect.no_equality
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
      file = "./tests/copilot.log",
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
  child.cmd(":Copilot status")
  local messages = child.cmd_capture(":messages")
  neq(string.find(messages, ".*not initialized.*"), nil)
end

-- eq(child.cmd_capture("notacommand"), "test")
-- child.cmd(":Copilot status")
-- local status = child.cmd_capture(":Copilot status")
-- local status = child.lua("return s.status()")
-- vim.print(status[0])

-- eq(child.get_screenshot(), "test")
-- coroutine.yield()
-- child.lua("s.status()")
-- local messages = child.cmd_capture(":messages")
-- vim.print(messages[0])
-- eq(child.lua("return conf.logger"), true)
-- eq(child.cmd_capture("Copilot auth"), "test")
-- eq(child.lua("return s.status()"), { "Hello world" })
--
--
--
-- T["lua_get()"] = function()
--   child.lua("_G.n = 0")
--   eq(child.lua_get("_G.n"), child.lua("return _G.n"))
-- end

-- `MiniTest.skip()` allows skipping rest of test execution while giving an
-- informative note. This test will pass with notes.
-- T["skip()"] = function()
--   if 1 + 1 == 2 then
--     MiniTest.skip("Apparently, 1 + 1 is 2")
--   end
--   error("1 + 1 is not 2")
-- end

-- `MiniTest.add_note()` allows adding notes. Final state will have
-- "with notes" suffix.
-- T["add_note()"] = function()
--   MiniTest.add_note("This test is not important.")
--   error("Custom error.")
-- end

-- `MiniTest.finally()` allows registering some function to be executed after
-- this case is finished executing (with or without an error).
-- T["finally()"] = function()
--   -- Add note only if test fails
--   MiniTest.finally(function()
--     if #MiniTest.current.case.exec.fails > 0 then
--       MiniTest.add_note("This test is flaky.")
--     end
--   end)
--   error("Expected error from time to time")
-- end

return T
