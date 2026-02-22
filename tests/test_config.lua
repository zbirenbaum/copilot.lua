local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_config")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = child.stop,
  },
})

T["config()"] = MiniTest.new_set()

T["config()"]["validate accepts valid config with defaults"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    local ok = pcall(config.validate, config)
    return ok
  ]])
  eq(result, true)
end

T["config()"]["validate rejects invalid panel type"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    local bad_config = vim.tbl_deep_extend("force", {}, config)
    bad_config.panel = "not a table"
    local ok = pcall(config.validate, bad_config)
    return ok
  ]])
  eq(result, false)
end

T["config()"]["validate rejects invalid suggestion type"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    local bad_config = vim.tbl_deep_extend("force", {}, config)
    bad_config.suggestion = 42
    local ok = pcall(config.validate, bad_config)
    return ok
  ]])
  eq(result, false)
end

T["config()"]["merge_with_user_configs applies user overrides"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.merge_with_user_configs({
      copilot_model = "gpt-4o",
      filetypes = { python = true },
    })
    return { model = config.copilot_model, python = config.filetypes.python }
  ]])
  eq(result.model, "gpt-4o")
  eq(result.python, true)
end

T["config()"]["merge_with_user_configs preserves defaults for unspecified fields"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.merge_with_user_configs({})
    return {
      node_cmd = config.copilot_node_command,
      disable_limit = config.disable_limit_reached_message,
    }
  ]])
  eq(result.node_cmd, "node")
  eq(result.disable_limit, false)
end

T["config()"]["copilot_node_command accepts string"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.merge_with_user_configs({
      copilot_node_command = "/usr/local/bin/node",
    })
    return config.copilot_node_command
  ]])
  eq(result, "/usr/local/bin/node")
end

T["config()"]["copilot_node_command accepts table"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.merge_with_user_configs({
      copilot_node_command = { "mise", "x", "node@lts", "--", "node" },
    })
    return config.copilot_node_command
  ]])
  eq(type(result), "table")
  eq(result[1], "mise")
end

T["config()"]["root_dir accepts string"] = function()
  local result = child.lua([[
    local config = require("copilot.config")
    config.merge_with_user_configs({
      root_dir = "/home/user/project",
    })
    return config.root_dir
  ]])
  eq(result, "/home/user/project")
end

return T
