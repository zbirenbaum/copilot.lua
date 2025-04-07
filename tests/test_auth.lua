local child = MiniTest.new_child_neovim()
local u = require("tests.utils")
local env = require("tests.env")

local config_path = require("copilot.auth").find_config_path()
local config_path_renamed = config_path .. "_temp_renamed"

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      if vim.fn.filereadable("./tests/logs/test_auth.log") == 1 then
        vim.fn.delete("./tests/logs/test_auth.log")
      end

      if vim.fn.isdirectory(config_path) == 1 then
        vim.fn.rename(config_path, config_path_renamed)
      end
    end,
    pre_case = function()
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
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

-- TODO: This test currently assumes you are not auth'd, so the token env var cannot be used
T["auth()"]["auth before attaching, should not give error"] = function()
  child.lua([[M.setup({
    logger = {
      file_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_auth.log",
      trace_lsp = "verbose",
      log_lsp_messages = true,
      trace_lsp_progress = true,
    },
  })]])

  vim.loop.sleep(500)
  child.cmd("Copilot auth")
  vim.loop.sleep(500)
  local messages = child.cmd_capture("messages")
  u.expect_match(messages, ".*Online.*Enabled.*")
end

T["auth()"]["auth issue replication"] = function()
  child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
  child.lua([[M.setup({
    logger = {
      file_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_auth.log",
      trace_lsp = "verbose",
      log_lsp_messages = true,
      trace_lsp_progress = true,
    },
  })]])

  vim.loop.sleep(500)
  child.cmd("Copilot auth")
  vim.loop.sleep(500)
  child.cmd("Copilot status")
  local messages = child.cmd_capture("messages")
  u.expect_match(messages, ".*Online.*Authenticated.*")
end

return T
