local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case()
      child.lua("s = require('copilot.status')")
      child.lua("c = require('copilot.client')")
    end,
    post_once = child.stop,
  },
})

T["client.config()"] = MiniTest.new_set()

T["client.config()"]["config, github-enterprise populated"] = function()
  child.lua([[M.setup({
    auth_provider_url = "https://someurl.com",
  })]])
  local settings = child.lua("return vim.inspect(c.config.settings)")
  u.expect_match(settings, "{.*github%-enterprise.*{.*uri.*https://someurl%.com.*}.*}")
end

T["client()"] = MiniTest.new_set()

T["client()"]["status info"] = function()
  child.configure_copilot()
  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      if messages:find(".*Online.*Enabled.*") then
        return true
      end
    end

    vim.wait(30000, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*Enabled.*")
end

return T
