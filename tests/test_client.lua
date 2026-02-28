local reference_screenshot = MiniTest.expect.reference_screenshot
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_client")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
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
      if messages:find(".*Online.*not yet requested.*") then
        return true
      end
    end

    vim.wait(500, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*attached.*")
end

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
  child.type_keys("123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

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

T["client()"]["suggestions work when attaching to second buffer in a row"] = function()
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
  child.type_keys("i123", "<Esc>")
  child.cmd("e tests/files/file3.txt")
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["client()"]["manually detached buffer stays detached"] = function()
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.type_keys("i123", "<Esc>")
  child.cmd("Copilot detach")
  child.cmd("e tests/files/file1.txt")
  child.type_keys("i123", "<Esc>")
  child.cmd("bp")
  child.type_keys("i123", "<Esc>")
  local filename = child.cmd_capture("echo expand('%:t')")
  u.expect_match("", filename)
  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      if messages:find(".*Online.*attached.*") then
        return true
      end
    end

    vim.wait(500, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*manually detached.*")
end

T["client()"]["suggestions work when lazy is set to false"] = function()
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
  child.type_keys("i123", "<Esc>")
  child.cmd("e tests/files/file3.txt")
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

T["client()"]["will not attach to buffer due to filetype exclusion"] = function()
  child.config.filetypes = [[
    ["*"] = false,
  ]]

  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"

  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

-- Reenable with new config
-- T["client()"]["auto_trigger off - will not attach automatically"] = function()
--   child.configure_copilot()
--   child.cmd("e test.txt")
--   child.type_keys("i", "<Esc>")
--   child.cmd("Copilot status")
--
--   local messages = child.lua([[
--     local messages = ""
--     local function has_passed()
--       messages = vim.api.nvim_exec("messages", { output = true }) or ""
--       if messages:find(".*Online.*attached.*") then
--         return true
--       end
--     end
--
--     vim.wait(500, function()
--       return has_passed()
--     end, 50)
--
--     return messages
--   ]])
--
--   u.expect_no_match(messages, ".*Online.*attached.*")
-- end

T["client()"]["auto_trigger off - will attach automatically"] = function()
  child.configure_copilot()
  child.cmd("e test.txt")
  child.type_keys("i", "<Esc>")
  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      if messages:find(".*Online.*attached.*") then
        return true
      end
    end

    vim.wait(500, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*attached.*")
end

T["client()"]["suggestion and panel off - will attach automatically"] = function()
  child.config.suggestion = "enabled = false,"
  child.configure_copilot()
  child.cmd("e test.txt")
  child.type_keys("i", "<Esc>")
  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      if messages:find(".*Online.*attached.*") then
        return true
      end
    end

    vim.wait(500, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*attached.*")
end

-- re-enable with added configuration
-- T["client()"]["auto_trigger off - will attach when requesting suggestion"] = function()
--   child.configure_copilot()
--   child.type_keys("i", "<M-l>", "<Esc>")
--   child.cmd("Copilot status")
--
--   local messages = child.lua([[
--     local messages = ""
--     local function has_passed()
--       messages = vim.api.nvim_exec("messages", { output = true }) or ""
--       if messages:find(".*Online.*attached.*") then
--         return true
--       end
--     end
--
--     vim.wait(500, function()
--       return has_passed()
--     end, 50)
--
--     return messages
--   ]])
--
--   u.expect_match(messages, ".*Online.*attached.*")
-- end

T["client()"]["saving file - will not yield URI not found error"] = function()
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i", "123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()
  child.type_keys("<Esc>")
  child.lua("M.suggested = false")
  child.cmd("w! tests/files/test.txt")
  child.type_keys("a8")
  child.wait_for_suggestion()
  local messages = child.cmd_capture("messages")

  u.expect_no_match(messages, "RPC.*Document for URI could not be found")
end

T["client()"]["renaming buffer with :file - detaches and re-attaches"] = function()
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i", "123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()
  child.type_keys("<Esc>")
  child.lua("M.suggested = false")

  -- Rename the buffer
  child.cmd("file tests/files/renamed.txt")
  child.lua("vim.wait(200, function() return false end, 10)")

  -- After rename, the buffer should still be attached (re-attached by BufFilePost handler)
  local is_attached = child.lua("return c.buf_is_attached(0)")
  MiniTest.expect.equality(is_attached, true)

  -- Verify the detach+re-attach happened by checking the log
  local log_has_reattach = child.lua([[
    local logfile = io.open("./tests/logs/test_client.log", "r")
    if not logfile then return false end
    local content = logfile:read("*a")
    logfile:close()
    return content:find("buffer filename changed") ~= nil
  ]])
  MiniTest.expect.equality(log_has_reattach, true)

  -- Verify suggestions still work after rename
  child.type_keys("a8")
  child.wait_for_suggestion()
  local messages = child.cmd_capture("messages")
  u.expect_no_match(messages, "RPC.*Document for URI could not be found")
end

T["client()"]["saving unnamed buffer with :w - detaches and re-attaches"] = function()
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i", "123", "<Esc>", "o456", "<Esc>", "o7")
  child.wait_for_suggestion()
  child.type_keys("<Esc>")
  child.lua("M.suggested = false")

  -- Save unnamed buffer to a file (changes buffer name)
  child.cmd("w! tests/files/saved_new.txt")
  child.lua("vim.wait(200, function() return false end, 10)")

  -- After save, the buffer should still be attached
  local is_attached = child.lua("return c.buf_is_attached(0)")
  MiniTest.expect.equality(is_attached, true)

  -- Verify the detach+re-attach happened by checking the log
  local log_has_reattach = child.lua([[
    local logfile = io.open("./tests/logs/test_client.log", "r")
    if not logfile then return false end
    local content = logfile:read("*a")
    logfile:close()
    return content:find("buffer filename changed") ~= nil
  ]])
  MiniTest.expect.equality(log_has_reattach, true)

  -- Verify suggestions still work after save
  child.type_keys("a8")
  child.wait_for_suggestion()
  local messages = child.cmd_capture("messages")
  u.expect_no_match(messages, "RPC.*Document for URI could not be found")
end

T["client()"]["should_attach returns false prevents buffer attachment"] = function()
  child.config.should_attach = [[function(bufnr, bufname)
    return false
  end]]
  child.configure_copilot()
  child.cmd("e test.txt")
  child.type_keys("i", "<Esc>")
  child.cmd("Copilot status")

  local messages = child.lua([[
    local messages = ""
    local function has_passed()
      messages = vim.api.nvim_exec("messages", { output = true }) or ""
      if messages:find(".*Online.*") then
        return true
      end
    end

    vim.wait(500, function()
      return has_passed()
    end, 50)

    return messages
  ]])

  u.expect_match(messages, ".*Online.*should_attach.*")
end

T["client()"]["disabled copilot does not spam warnings on buffer enter"] = function()
  -- Override lsp.setup to return false, simulating a failed initialization
  -- (e.g. Node.js not found or wrong version). This sets is_disabled=true
  -- in client.setup() but suggestion autocmds are still created.
  child.lua([[
    local lsp = require("copilot.lsp")
    lsp.setup = function(_, _)
      return false
    end
  ]])

  -- Intercept vim.notify to count "copilot is disabled" warnings
  child.lua([[
    _G.disabled_warning_count = 0
    local original_notify = vim.notify
    vim.notify = function(msg, level, opts)
      if type(msg) == "string" and msg:find("copilot is disabled") then
        _G.disabled_warning_count = _G.disabled_warning_count + 1
      end
      return original_notify(msg, level, opts)
    end
  ]])

  -- Setup copilot with auto_trigger - client will be disabled but suggestion
  -- autocmds are still created, causing buf_attach to be called on every
  -- insert mode action
  child.lua([[
    M.setup({
      suggestion = { auto_trigger = true },
      filetypes = { ["*"] = true },
    })
  ]])

  -- Trigger multiple insert mode entries across buffers.
  -- Each InsertEnter and CursorMovedI fires the suggestion autocmd,
  -- which calls buf_attach, which warns when client is disabled.
  child.type_keys("i", "abc", "<Esc>")
  child.cmd("e tests/files/file1.txt")
  child.type_keys("i", "def", "<Esc>")
  child.cmd("e tests/files/file2.txt")
  child.type_keys("i", "ghi", "<Esc>")

  -- Allow scheduled vim.notify calls to execute
  child.lua("vim.wait(500, function() return false end, 50)")

  local count = child.lua("return _G.disabled_warning_count")

  -- The warning should appear at most once, not on every insert mode action.
  -- See: https://github.com/zbirenbaum/copilot.lua/issues/629
  MiniTest.expect.equality(count, 0)
end

T["client()"]["on_buf_enter skips filetype check for non-buflisted buffers"] = function()
  child.configure_copilot()

  -- Create a non-buflisted buffer with a filetype mismatch and trigger BufEnter.
  -- This simulates floating windows / preview buffers that should not trigger
  -- the filetype-change detach+re-attach cycle.
  child.lua([[
    local util = require("copilot.util")

    local buf = vim.api.nvim_create_buf(false, true)  -- nobuflisted, scratch
    vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })

    -- Manually set previous_ft to simulate a buffer that was previously attached.
    -- buf_attach won't succeed for non-buflisted buffers (should_attach rejects them),
    -- so previous_ft wouldn't normally be set. In the real bug scenario, this state
    -- can be reached through various pathways.
    util.set_buffer_previous_ft(buf, "lua")

    -- Change filetype on same non-buflisted buffer
    vim.api.nvim_set_option_value("filetype", "python", { buf = buf })

    -- Trigger BufEnter (simulating entering the buffer)
    vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })

    -- Wait for scheduled callbacks to execute
    vim.wait(200, function() return false end, 10)
  ]])

  -- The filetype change should NOT cause detach+re-attach for non-buflisted buffers
  local detach_was_called = child.lua([[
    local log_content = ""
    local logfile = io.open("./tests/logs/test_client.log", "r")
    if logfile then
      log_content = logfile:read("*a")
      logfile:close()
    end
    -- If the guard works, we should NOT see "filetype changed" for non-buflisted buffers
    return log_content:find("filetype changed, detaching and re%-attaching") ~= nil
  ]])

  MiniTest.expect.equality(detach_was_called, false)
end

return T
