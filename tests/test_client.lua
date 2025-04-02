local eq = MiniTest.expect.equality
local neq = MiniTest.expect.no_equality
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      -- Restart child process with custom 'init.lua' script
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.lua([[M = require('copilot')]])
      child.lua([[c = require('copilot.client')]])
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
      print_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_client.log",
    },     
  })]])
end

T["client()"] = MiniTest.new_set()

T["client()"]["config, github-enterprise populated"] = function()
  child.lua([[M.setup({
    auth_provider_url = "https://someurl.com",
  })]])
  -- child.lua([[c.enable()]])
  -- child.lua([[c.attach({ force = true })]])
  -- local test = child.lua([[return vim.inspect(M)]])
  -- print(test)
  local settings = child.lua([[return vim.inspect(c.config.settings)]])

  -- local messages = child.cmd_capture(":messages")
  print(settings)
  -- neq(string.find(messages, ".*uri.*https://someurl%.com"), nil)
end

return T
