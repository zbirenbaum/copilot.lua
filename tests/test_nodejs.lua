local eq = MiniTest.expect.equality
local stub = require("tests.stubs.nodejs")

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

T["get_node_version()"]["default node command"] = function()
  local captured_args = stub.valid_node(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup()

    local version, error = nodejs.get_node_version()

    eq(version, stub.valid_node_version)
    eq(error, nil)
  end)
  eq(captured_args, { "node", "--version" })
end

T["get_node_version()"]["custom node command as string"] = function()
  local captured_args = stub.valid_node(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/usr/local/bin/node")

    local version, error = nodejs.get_node_version()

    eq(version, stub.valid_node_version)
    eq(error, nil)
  end)
  eq(captured_args, { "/usr/local/bin/node", "--version" })
end

T["get_node_version()"]["custom node command as string with spaces"] = function()
  local captured_args = stub.valid_node(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/path to/node")

    local version, error = nodejs.get_node_version()

    eq(version, stub.valid_node_version)
    eq(error, nil)
  end)
  eq(captured_args, { "/path to/node", "--version" })
end

T["get_node_version()"]["custom node command as table"] = function()
  local captured_args = stub.valid_node(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup({ "mise", "x", "node@lts", "--", "node" })

    local version, error = nodejs.get_node_version()

    eq(version, stub.valid_node_version)
    eq(error, nil)
  end)
  eq(captured_args, { "mise", "x", "node@lts", "--", "node", "--version" })
end

T["get_node_version()"]["handles vim.system failure"] = function()
  local captured_args = stub.process("", -1, true, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("node")

    local _, error = nodejs.get_node_version()
    error = error or ""

    eq(error:find("Could not determine Node.js version") ~= nil, true)
  end)
  eq(captured_args, { "node", "--version" })
end

T["get_node_version()"]["handles process with non-zero exit code"] = function()
  local captured_args = stub.process("", 127, false, function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("nonexistent-node")

    local _, error = nodejs.get_node_version()
    error = error or ""

    eq(error:find("Could not determine Node.js version") ~= nil, true)
  end)
  eq(captured_args, { "nonexistent-node", "--version" })
end

T["get_node_version()"]["validates node version requirement"] = function()
  local captured_args = stub.invalid_node(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("node")

    local _, error = nodejs.get_node_version()
    error = error or ""

    eq(error:find("Node.js version 20 or newer required") ~= nil, true)
  end)
  eq(captured_args, { "node", "--version" })
end

T["get_execute_command()"] = MiniTest.new_set()

T["get_execute_command()"]["default node command, default server path"] = function()
  local captured_path = stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    eq(nodejs.setup(), true)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "node", vim.fn.expand(stub.default_server_path), "--stdio" })
  end)
  eq(captured_path, stub.default_server_path)
end

T["get_execute_command()"]["default node command, custom server path"] = function()
  stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    eq(nodejs.setup(nil, vim.fn.expand(stub.custom_server_path)), true)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "node", vim.fn.expand(stub.custom_server_path), "--stdio" })
  end)
end

T["get_execute_command()"]["custom node command as string, default server path"] = function()
  local captured_path = stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    eq(nodejs.setup("/usr/local/bin/node"), true)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "/usr/local/bin/node", vim.fn.expand(stub.default_server_path), "--stdio" })
  end)
  eq(captured_path, stub.default_server_path)
end

T["get_execute_command()"]["custom node command as string, custom server path"] = function()
  stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/usr/local/bin/node", stub.custom_server_path)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "/usr/local/bin/node", stub.custom_server_path, "--stdio" })
  end)
end

T["get_execute_command()"]["custom node command as string with spaces, default server path"] = function()
  local captured_path = stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/path to/node")
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "/path to/node", vim.fn.expand(stub.default_server_path), "--stdio" })
  end)
  eq(captured_path, stub.default_server_path)
end

T["get_execute_command()"]["custom node command as string with spaces, custom server path"] = function()
  stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup("/path to/node", stub.custom_server_path)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "/path to/node", stub.custom_server_path, "--stdio" })
  end)
end

T["get_execute_command()"]["custom node command as table, default server path"] = function()
  local captured_path = stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup({ "mise", "x", "node@lts", "--", "node" })
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "mise", "x", "node@lts", "--", "node", vim.fn.expand(stub.default_server_path), "--stdio" })
  end)
  eq(captured_path, stub.default_server_path)
end

T["get_execute_command()"]["custom node command as table, custom server path"] = function()
  stub.get_runtime_server_path(function()
    local nodejs = require("copilot.lsp.nodejs")
    nodejs.setup({ "mise", "x", "node@lts", "--", "node" }, stub.custom_server_path)
    local cmd = nodejs.get_execute_command()
    eq(cmd, { "mise", "x", "node@lts", "--", "node", stub.custom_server_path, "--stdio" })
  end)
end

return T
