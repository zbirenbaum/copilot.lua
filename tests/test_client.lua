local child = MiniTest.new_child_neovim()
local u = require("tests.utils")
local env = require("tests.env")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      if vim.fn.filereadable("./tests/logs/test_client.log") == 1 then
        vim.fn.delete("./tests/logs/test_client.log")
      end
    end,
    pre_case = function()
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.lua([[M = require('copilot')]])
      child.lua([[c = require('copilot.client')]])
      child.lua([[s = require('copilot.status')]])
      child.lua([[cmd = require('copilot.command')]])
      child.lua([[a = require('copilot.api')]])
      child.lua("logger = require('copilot.logger')")
      -- child.lua([[require("osv").launch({ port = 8086 })]])
      child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
    end,
    post_once = child.stop,
  },
})

T["client.config()"] = MiniTest.new_set()

T["client.config()"]["config, github-enterprise populated"] = function()
  child.lua([[M.setup({
    auth_provider_url = "https://someurl.com",
  })]])
  local settings = child.lua([[return vim.inspect(c.config.settings)]])
  u.expect_match(settings, "{.*github%-enterprise.*{.*uri.*https://someurl%.com.*}.*}")
end

T["client()"] = MiniTest.new_set()

-- T["client()"]["buf_attach"] = function()
--   child.lua([[M.setup({
--     logger = {
--       file_log_level = vim.log.levels.TRACE,
--       file = "./tests/logs/test_client.log",
--     },
--   })]])
--
--   child.lua([[cmd.enable()]])
--   child.lua([[cmd.attach({ force = true })]])
--   local messages = child.cmd_capture("messages")
--   vim.loop.sleep(500)
--   -- u.expect_match(messages, "Copilot: Copilot attached to buffer")
--   print(messages)
-- end

-- TODO: The sleep is a poor way to wait for the scheduled job to be done...
-- have not found a better way yet.
T["client()"]["status info"] = function()
  child.lua([[M.setup({
    logger = {
      file_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_client.log",
    },
  })]])

  -- child.lua("vim.wait(0)") -- does not seem to be enough to force the async job
  vim.loop.sleep(500)
  child.cmd("Copilot status")
  vim.loop.sleep(500)
  local messages = child.cmd_capture("messages")
  u.expect_match(messages, ".*Online.*Enabled.*")
end

return T
