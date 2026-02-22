local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_binary")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(false)
    end,
    post_once = child.stop,
  },
})

T["binary()"] = MiniTest.new_set()

T["binary()"]["get_copilot_server_info returns valid info for current OS"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.copilot_server_info = nil
    local info = binary.get_copilot_server_info()
    return {
      has_path = info.path ~= nil and info.path ~= "",
      has_filename = info.filename ~= nil and info.filename ~= "",
      has_absolute_path = info.absolute_path ~= nil,
    }
  ]])
  eq(result.has_path, true)
  eq(result.has_filename, true)
  eq(result.has_absolute_path, true)
end

T["binary()"]["get_copilot_server_info caches result"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.copilot_server_info = nil
    local info1 = binary.get_copilot_server_info()
    local info2 = binary.get_copilot_server_info()
    return info1.path == info2.path and info1.filename == info2.filename
  ]])
  eq(result, true)
end

T["binary()"]["get_server_path returns absolute filepath"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.copilot_server_info = nil
    local path = binary.get_server_path()
    return type(path) == "string" and #path > 0
  ]])
  eq(result, true)
end

T["binary()"]["setup with non-existent custom path returns early"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local ok = pcall(binary.setup, "/nonexistent/path/to/server")
    return ok
  ]])
  eq(result, true)
end

T["binary()"]["get_server_info returns path/filename when client is provided"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.copilot_server_info = nil
    local info = binary.get_copilot_server_info()
    local server_info = binary.get_server_info({})
    return {
      server_info = server_info,
      expected = info.path .. "/" .. info.filename,
    }
  ]])
  eq(result.server_info, result.expected)
end

T["binary()"]["get_server_info returns not running when client is nil"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.copilot_server_info = nil
    local info = binary.get_copilot_server_info()
    local server_info = binary.get_server_info(nil)
    return {
      server_info = server_info,
      expected = info.path .. "/" .. info.filename .. " " .. "not running",
    }
  ]])
  eq(result.server_info, result.expected)
end

T["binary()"]["download_file rejects when neither curl nor wget is available"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    -- Mock vim.fn.executable to return 0 for both curl and wget
    local orig_executable = vim.fn.executable
    vim.fn.executable = function(cmd)
      if cmd == "curl" or cmd == "wget" then
        return 0
      end
      return orig_executable(cmd)
    end

    -- Access download_file indirectly via init() which calls download_file
    -- We need to reset state and set up server info so init() reaches download_file
    binary.initialized = false
    binary.initialization_failed = false
    binary.copilot_server_info = {
      path = "linux-x64",
      filename = "copilot-language-server-test",
      absolute_path = "/tmp/copilot-test",
      absolute_filepath = "/tmp/copilot-test/copilot-language-server-test",
      extracted_filename = "copilot-language-server",
    }

    local captured_error = nil
    local logger = require("copilot.logger")
    local orig_error = logger.error
    logger.error = function(msg, ...)
      captured_error = msg
    end

    local ok = binary.init()

    logger.error = orig_error
    vim.fn.executable = orig_executable
    return {
      ok = ok,
      has_error = captured_error ~= nil,
      error_msg = captured_error or "",
    }
  ]])
  eq(result.ok, false)
  eq(result.has_error, true)
end

T["binary()"]["download_file does not reject when wget is available but curl is not"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    -- Mock vim.fn.executable: curl unavailable, wget available
    local orig_executable = vim.fn.executable
    vim.fn.executable = function(cmd)
      if cmd == "curl" then return 0 end
      if cmd == "wget" then return 1 end
      return orig_executable(cmd)
    end

    binary.initialized = false
    binary.initialization_failed = false
    binary.copilot_server_info = {
      path = "linux-x64",
      filename = "copilot-language-server-test",
      absolute_path = "/tmp/copilot-test",
      absolute_filepath = "/tmp/copilot-test/copilot-language-server-test",
      extracted_filename = "copilot-language-server",
    }

    local neither_error = false
    local logger = require("copilot.logger")
    local orig_error = logger.error
    local orig_notify = logger.notify
    logger.notify = function() end
    logger.error = function(msg, ...)
      if type(msg) == "string" and msg:find("neither") then
        neither_error = true
      end
    end

    binary.init()

    logger.error = orig_error
    logger.notify = orig_notify
    vim.fn.executable = orig_executable
    return neither_error
  ]])
  -- Should NOT get the "neither curl nor wget" error when wget IS available
  eq(result, false)
end

return T
