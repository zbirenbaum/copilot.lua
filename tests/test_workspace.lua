local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_workspace")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
      child.configure_copilot()
    end,
    post_once = child.stop,
  },
})

T["workspace()"] = MiniTest.new_set()

T["workspace()"]["add with empty args logs error"] = function()
  local result = child.lua([[
    local workspace = require("copilot.workspace")
    local captured_error = nil
    local logger = require("copilot.logger")
    local orig_error = logger.error
    logger.error = function(msg, ...)
      captured_error = msg
    end
    workspace.add({ args = "" })
    logger.error = orig_error
    return captured_error ~= nil
  ]])
  eq(result, true)
end

T["workspace()"]["add with nil args logs error"] = function()
  local result = child.lua([[
    local workspace = require("copilot.workspace")
    local captured_error = nil
    local logger = require("copilot.logger")
    local orig_error = logger.error
    logger.error = function(msg, ...)
      captured_error = msg
    end
    workspace.add({ args = nil })
    logger.error = orig_error
    return captured_error ~= nil
  ]])
  eq(result, true)
end

T["workspace()"]["utils.add_workspace_folder rejects non-string path"] = function()
  local result = child.lua([[
    local utils = require("copilot.workspace.utils")
    return utils.add_workspace_folder(123)
  ]])
  eq(result, false)
end

T["workspace()"]["utils.add_workspace_folder rejects non-existent directory"] = function()
  local result = child.lua([[
    local utils = require("copilot.workspace.utils")
    return utils.add_workspace_folder("/nonexistent/path/that/does/not/exist")
  ]])
  eq(result, false)
end

T["workspace()"]["utils.add_workspace_folder accepts valid directory"] = function()
  local result = child.lua([[
    local utils = require("copilot.workspace.utils")
    local tmpdir = vim.uv.os_tmpdir()
    return utils.add_workspace_folder(tmpdir)
  ]])
  eq(result, true)
end

T["workspace()"]["utils.add_workspace_folder detects duplicates"] = function()
  local result = child.lua([[
    local utils = require("copilot.workspace.utils")
    local config = require("copilot.config")
    config.workspace_folders = nil
    local tmpdir = vim.uv.os_tmpdir()
    local first = utils.add_workspace_folder(tmpdir)
    local second = utils.add_workspace_folder(tmpdir)
    local folder_count = #config.workspace_folders
    return { first = first, second = second, folder_count = folder_count }
  ]])
  eq(result.first, true)
  -- Second add of same folder should return nil (duplicate detected)
  eq(result.second, nil)
  -- Should only have one entry, not two
  eq(result.folder_count, 1)
end

return T
