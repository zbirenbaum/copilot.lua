local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      -- Reset the module state before each test
      package.loaded["copilot.lsp.nodejs"] = nil
    end,
  },
})

T["get_node_version()"] = MiniTest.new_set()

local function stub_process(stdout, code, fail, callback)
  local captured_args = nil
  local original_vim_system = vim.system
  vim.system = function(cmd, opts)
    captured_args = cmd
    if fail then
      error("Command failed")
    end
    return {
      wait = function()
        return {
          stdout = stdout .. "\n",
          code = code
        }
      end
    }
  end
  callback()
  vim.system = original_vim_system
  return captured_args
end

T["get_node_version()"]["default node command"] = function()
  captured_args = stub_process("v20.10.0", 0, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup()

    local version, error = nodejs.get_node_version()

    eq(version, "20.10.0")
    eq(error, nil)
  end)
  eq(captured_args, { "node", "--version" })
end

T["get_node_version()"]["custom node command as string"] = function()
  local captured_args = stub_process("v20.10.0", 0, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/usr/local/bin/node")

    local version, error = nodejs.get_node_version()

    eq(version, "20.10.0")
    eq(error, nil)
  end)
  eq(captured_args, { "/usr/local/bin/node", "--version" })
end

T["get_node_version()"]["custom node command as string with spaces"] = function()
  local captured_args = stub_process("v20.10.0", 0, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/path to/node")

    local version, error = nodejs.get_node_version()

    eq(version, "20.10.0")
    eq(error, nil)
  end)
  eq(captured_args, { "/path to/node", "--version" })
end

T["get_node_version()"]["handles vim.system failure"] = function()
  local captured_args = stub_process("", -1, true, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("node")

    local version, error = nodejs.get_node_version()

    eq(version, "")
    -- Error should contain failure information
    local expected_error_pattern = "Could not determine Node%.js version"
    eq(type(error), "string")
    eq(error:find(expected_error_pattern) ~= nil, true)
  end)
end

T["get_node_version()"]["handles process with non-zero exit code"] = function()
  local captured_args = stub_process("", 127, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("nonexistent-node")

    local version, error = nodejs.get_node_version()

    eq(version, "")
    -- Error should contain failure information with exit code
    local expected_error_pattern = "Could not determine Node%.js version"
    eq(type(error), "string")
    eq(error:find(expected_error_pattern) ~= nil, true)
    eq(error:find("127") ~= nil, true)
  end)
  eq(captured_args, { "nonexistent-node", "--version" })
end

T["get_node_version()"]["validates node version requirement"] = function()
  local captured_args = stub_process("v18.17.0", 0, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("node")

    local version, error = nodejs.get_node_version()

    eq(version, "18.17.0")
    -- Error should indicate version requirement not met
    eq(type(error), "string")
    eq(error:find("Node%.js version 20 or newer required") ~= nil, true)
    eq(error:find("18%.17%.0") ~= nil, true)
  end)
  eq(captured_args, { "node", "--version" })
end

T["get_execute_command()"] = MiniTest.new_set()

T["get_execute_command()"]["default node command"] = function()
  local nodejs = require("copilot.lsp.nodejs")
  nodejs.setup()
  local cmd = nodejs.get_execute_command()
  eq(cmd, { "node", nodejs.server_path, "--stdio" })
end

T["get_execute_command()"]["custom node command as string"] = function()
  local nodejs = require("copilot.lsp.nodejs")
  nodejs.setup("/usr/local/bin/node")
  local cmd = nodejs.get_execute_command()
  eq(cmd, { "/usr/local/bin/node", nodejs.server_path, "--stdio" })
end

T["get_execute_command()"]["custom node command as string with spaces"] = function()
  local nodejs = require("copilot.lsp.nodejs")
  nodejs.setup("/path to/node")
  local cmd = nodejs.get_execute_command()
  eq(cmd, { "/path to/node", nodejs.server_path, "--stdio" })
end

return T
