local reference_screenshot = MiniTest.expect.reference_screenshot
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

    vim.wait(5000, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*Enabled.*")
end

T["client()"] = MiniTest.new_set()

T["client()"]["suggestions work when multiple files open with should_attach logic"] = function()
  child.config.should_attach = [[function(bufnr, bufname)
    local buffername = bufname:match("([^/\\]+)$") or ""

    if not _G.bufnames then
      _G.bufnames  = ''
    end

    _G.bufnames = _G.bufnames .. ' ; ' .. buffername.. ' (' .. tostring(bufnr) .. ')'

    if buffername == "file2.txt" then
      return true
    end

    return false
  end]]
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.cmd("e tests/files/file1.txt")
  child.cmd("e tests/files/file2.txt")
  child.type_keys("i")
  -- child.cmd("e tests/files/file3.txt")
  child.type_keys("123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()
  local bufnames = child.lua("return tostring(_G.bufnames)")

  local messages = child.lua([[
    return vim.api.nvim_exec("messages", { output = true }) or ""
  ]])

  -- convert buffername to only the file name
  -- buffername = buffername:match("([^/\\]+)$")

  -- u.expect_match(buffername, "file3.txt")
  print("Messages: " .. messages)
  print("bufnames: " .. bufnames)

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["client()"]["suggestions off when previous file only should_attach"] = function()
  child.config.should_attach = [[function(bufnr, bufname)
    local buffername = bufname:match("([^/\\]+)$") or ""

    if buffername == "file1.txt" then
      return true
    end

    return false
  end]]
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.cmd("e tests/files/file1.txt")
  child.cmd("e tests/files/file2.txt")
  child.type_keys("i")
  -- child.cmd("e tests/files/file3.txt")
  child.type_keys("123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["client()"]["suggestions off when previous file only should_attach - 2"] = function()
  child.config.should_attach = [[function(bufnr, bufname)
    local buffername = bufname:match("([^/\\]+)$") or ""

    if buffername == "file2.txt" then
      return true
    end

    return false
  end]]
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.cmd("e tests/files/file1.txt")
  child.cmd("e tests/files/file2.txt")
  child.type_keys("i")
  child.cmd("e tests/files/file3.txt")
  child.type_keys("123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["client()"]["suggestions work when already in insert mode and opening file - 3"] = function()
  child.config.should_attach = [[function(bufnr, bufname)
    local buffername = bufname:match("([^/\\]+)$") or ""

    if buffername == "file3.txt" then
      return true
    end

    return false
  end]]
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.cmd("e tests/files/file1.txt")
  child.cmd("e tests/files/file2.txt")
  child.type_keys("i")
  child.cmd("e tests/files/file3.txt")
  child.type_keys("123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

return T
