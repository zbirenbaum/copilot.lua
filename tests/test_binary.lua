local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_binary")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.run_pre_case(false)
    end,
    post_once = child.stop,
  },
})

T["binary()"] = MiniTest.new_set()

T["binary()"]["uses installer entrypoint"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local installer = require("copilot.lsp.installer")
    local called = false
    installer.ensure = function(server_type, callback)
      called = server_type == "binary"
      callback(nil, "/cache/copilot/1.527.5/linux-x64/generations/aaaaaaaa-generation/copilot-language-server")
    end
    local err
    binary.setup(nil, function(setup_err)
      err = setup_err
    end)
    return { called = called, err = err, path = binary.server_path }
  ]])
  eq(result.called, true)
  eq(result.err, nil)
  eq(result.path, "/cache/copilot/1.527.5/linux-x64/generations/aaaaaaaa-generation/copilot-language-server")
end

T["binary()"]["installer errors reach callback without sticky state"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local installer = require("copilot.lsp.installer")
    installer.ensure = function(_, callback)
      callback("download failed")
    end
    local received
    binary.setup(nil, function(err)
      received = err
    end)
    return received
  ]])
  eq(result, "download failed")
end

T["binary()"]["custom path bypasses installer"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local installer = require("copilot.lsp.installer")
    local called = false
    installer.ensure = function()
      called = true
    end
    local original_readable = vim.fn.filereadable
    local original_executable = vim.fn.executable
    vim.fn.filereadable = function(path)
      return path == "/custom/server" and 1 or original_readable(path)
    end
    vim.fn.executable = function(path)
      return path == "/custom/server" and 1 or original_executable(path)
    end
    local received
    binary.setup("/custom/server", function(err)
      received = err
    end)
    vim.fn.filereadable = original_readable
    vim.fn.executable = original_executable
    return { called = called, err = received, path = binary.server_path }
  ]])
  eq(result.called, false)
  eq(result.err, nil)
  eq(result.path, "/custom/server")
end

T["binary()"]["readable but non-executable custom path is rejected"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local original_readable = vim.fn.filereadable
    local original_executable = vim.fn.executable
    vim.fn.filereadable = function(path)
      return path == "/custom/script" and 1 or original_readable(path)
    end
    vim.fn.executable = function(path)
      return path == "/custom/script" and 0 or original_executable(path)
    end
    local received
    binary.setup("/custom/script", function(err)
      received = err
    end)
    vim.fn.filereadable = original_readable
    vim.fn.executable = original_executable
    return { has_error = received ~= nil, error = received or "" }
  ]])
  eq(result.has_error, true)
  eq(result.error:find("not found") ~= nil, true)
end

T["binary()"]["get_server_info describes running and stopped states"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.server_path = "/cache/copilot/linux-x64/copilot-language-server"
    binary.copilot_server_info = {
      path = binary.server_path,
      filename = binary.server_path,
    }
    return {
      running = binary.get_server_info({}),
      stopped = binary.get_server_info(nil),
    }
  ]])
  eq(result.running, "/cache/copilot/linux-x64/copilot-language-server")
  eq(result.stopped, "/cache/copilot/linux-x64/copilot-language-server not running")
end

T["binary()"]["get_server_info uses the installed entrypoint"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    binary.server_path = "/cache/copilot/1.527.5/linux-x64/copilot-language-server"
    binary.copilot_server_info = nil
    return binary.get_server_info({})
  ]])
  eq(result, "/cache/copilot/1.527.5/linux-x64/copilot-language-server")
end

T["binary()"]["native Windows arm64 command uses installer path"] = function()
  local result = child.lua([[
    local binary = require("copilot.lsp.binary")
    local installer = require("copilot.lsp.installer")
    local original_uname = vim.loop.os_uname
    local original_system = vim.system
    local system_calls = 0
    vim.loop.os_uname = function()
      return { sysname = "Windows_NT", machine = "ARM64" }
    end
    installer.ensure = function(_, callback)
      callback(nil, "/cache/copilot/server.exe")
    end
    vim.system = function()
      system_calls = system_calls + 1
      error("Node must not be probed")
    end
    binary.copilot_server_info = nil
    local received
    binary.setup(nil, function(err)
      received = err
    end)
    local command = binary.get_execute_command()
    vim.loop.os_uname = original_uname
    vim.system = original_system
    return { err = received, command = command, system_calls = system_calls }
  ]])
  eq(result.err, nil)
  eq(result.command, { "/cache/copilot/server.exe", "--stdio" })
  eq(result.system_calls, 0)
end

return T
