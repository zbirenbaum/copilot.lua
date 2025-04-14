local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_auth")
local u = require("tests.utils")

local config_path = require("copilot.auth").find_config_path() .. "/github-copilot"
local config_path_renamed = config_path .. "_temp_renamed"

--TODO: find a way to not mess with folders
local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      if vim.fn.isdirectory(config_path) == 1 then
        vim.fn.rename(config_path, config_path_renamed)
      end
    end,
    pre_case = function()
      child.run_pre_case()
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

T["auth()"]["auth before attaching, should not give error"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Authenticated as GitHub user.*") ~= nil
    end

    vim.wait(30000, function()
      return has_passed()
    end, 50)

    return messages 
  ]])

  u.expect_match(messages, ".*Authenticated as GitHub user.*")
end

T["auth()"]["auth issue replication"] = function()
  child.configure_copilot()
  child.cmd("Copilot auth")

  child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Authenticated as GitHub user.*") ~= nil
    end

    vim.wait(30000, function()
      return has_passed()
    end, 50)
  ]])

  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      return string.find(messages, ".*Online.*Enabled.*") ~= nil
    end

    vim.wait(30000, function()
      return has_passed()
    end, 50)

    return messages 
  ]])

  u.expect_match(messages, ".*Online.*Enabled.*")
end

return T
