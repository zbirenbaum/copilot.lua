local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_auth")
local u = require("tests.utils")

local config_path = require("copilot.auth").find_config_path()
local config_path_renamed = config_path .. "_temp_renamed"

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      if vim.fn.isdirectory(config_path) == 1 then
        vim.fn.rename(config_path, config_path_renamed)
      end
    end,
    pre_case = function()
      child.run_pre_case()
      child.lua("M = require('copilot')")
      child.lua("c = require('copilot.client')")
      child.lua("s = require('copilot.status')")
      child.lua("cmd = require('copilot.command')")
      child.lua("a = require('copilot.api')")
      child.lua("logger = require('copilot.logger')")
    end,
    post_once = function()
      child.stop()

      if vim.fn.isdirectory(config_path_renamed) == 1 then
        vim.fn.rename(config_path_renamed, config_path)
      end
    end,
  },
})

T["auth()"] = MiniTest.new_set()

-- TODO: callback for this too
T["auth()"]["auth before attaching, should not give error"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")
  vim.loop.sleep(3000)
  local messages = child.cmd_capture("messages")
  u.expect_match(messages, ".*Authenticated as GitHub user.*")
end

T["auth()"]["auth issue replication"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")
  vim.loop.sleep(2000)
  child.cmd("Copilot status")
  vim.loop.sleep(500)
  local messages = child.cmd_capture("messages")
  u.expect_match(messages, ".*Online.*Enabled.*")
end

return T
