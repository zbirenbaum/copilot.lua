local eq = MiniTest.expect.equality
local stub = require("tests.stubs.nodejs")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      package.loaded["copilot.lsp.nodejs"] = nil
      stub.nodejs = require("copilot.lsp.nodejs")
    end,
  },
})

local function setup(node_function, node_command, custom_path, callback)
  stub.install(function()
    node_function(function()
      stub.nodejs.setup(node_command, custom_path, callback)
    end)
  end)
end

T["get_node_version()"] = MiniTest.new_set()

T["get_node_version()"]["validates Node.js 22"] = function()
  local captured = stub.valid_node_22(function()
    stub.nodejs.node_command = "node"
    local version, err = stub.nodejs.get_node_version()
    eq(version, stub.valid_node_version_22)
    eq(err, nil)
  end)
  eq(captured, { "node", "--version" })
end

T["get_node_version()"]["rejects older Node.js"] = function()
  stub.invalid_node(function()
    stub.nodejs.node_command = "node"
    local _, err = stub.nodejs.get_node_version()
    eq(err:find("Node.js version 22 or newer required") ~= nil, true)
  end)
end

T["setup()"] = MiniTest.new_set()

T["setup()"]["uses installer entrypoint after version validation"] = function()
  local received
  setup(stub.valid_node_22, nil, nil, function(err)
    received = err
  end)
  eq(received, nil)
  eq(stub.nodejs.server_path, stub.default_server_path)
end

T["setup()"]["custom path bypasses installer"] = function()
  local installer_called = false
  local installer = require("copilot.lsp.installer")
  local original_ensure = installer.ensure
  installer.ensure = function()
    installer_called = true
  end
  local original_readable = vim.fn.filereadable
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.filereadable = function(path)
    return path == stub.custom_server_path and 1 or original_readable(path)
  end
  local received
  stub.valid_node_22(function()
    stub.nodejs.setup(nil, stub.custom_server_path, function(err)
      received = err
    end)
  end)
  vim.fn.filereadable = original_readable
  installer.ensure = original_ensure
  eq(received, nil)
  eq(installer_called, false)
  eq(stub.nodejs.server_path, stub.custom_server_path)
end

T["setup()"]["invalid Node.js does not request installation"] = function()
  local installer_called = false
  local installer = require("copilot.lsp.installer")
  local original_ensure = installer.ensure
  installer.ensure = function()
    installer_called = true
  end
  local received
  stub.invalid_node(function()
    stub.nodejs.setup(nil, nil, function(err)
      received = err
    end)
  end)
  installer.ensure = original_ensure
  eq(installer_called, false)
  eq(received:find("Node.js version 22 or newer required") ~= nil, true)
end

T["setup()"]["retries version probe after a failed command"] = function()
  local first_error
  stub.invalid_node(function()
    stub.nodejs.setup("node", nil, function(err)
      first_error = err
    end)
  end)
  local second_error
  stub.install(function()
    stub.valid_node_25(function()
      stub.nodejs.setup("node", nil, function(err)
        second_error = err
      end)
    end)
  end)
  eq(first_error:find("Node.js version 22 or newer required") ~= nil, true)
  eq(second_error, nil)
end

T["setup()"]["revalidates when the node command changes"] = function()
  local first_error
  stub.install(function()
    stub.valid_node_25(function()
      stub.nodejs.setup("node-25", nil, function(err)
        first_error = err
      end)
    end)
  end)
  local second_error
  stub.invalid_node(function()
    stub.nodejs.setup("node-10", nil, function(err)
      second_error = err
    end)
  end)
  eq(first_error, nil)
  eq(second_error:find("Node.js version 22 or newer required") ~= nil, true)
end

T["setup()"]["reports command failure and nonzero exit"] = function()
  local process_error
  stub.process("", -1, true, function()
    stub.nodejs.setup("broken-node", nil, function(err)
      process_error = err
    end)
  end)
  local exit_error
  stub.process("", 127, false, function()
    stub.nodejs.setup("missing-node", nil, function(err)
      exit_error = err
    end)
  end)
  eq(process_error:find("Could not determine Node.js version") ~= nil, true)
  eq(exit_error:find("Could not determine Node.js version") ~= nil, true)
end

T["get_execute_command()"] = MiniTest.new_set()

T["get_execute_command()"]["adds sqlite flag for Node 22"] = function()
  setup(stub.valid_node_22, nil, nil, function(err)
    eq(err, nil)
    eq(stub.nodejs.get_execute_command(), { "node", "--experimental-sqlite", stub.default_server_path, "--stdio" })
  end)
end

T["get_execute_command()"]["preserves custom command and server path"] = function()
  local original_readable = vim.fn.filereadable
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.filereadable = function(path)
    return path == stub.custom_server_path and 1 or original_readable(path)
  end
  stub.valid_node_24(function()
    stub.nodejs.setup({ "mise", "x", "node@lts", "--", "node" }, stub.custom_server_path, function(err)
      eq(err, nil)
      eq(stub.nodejs.get_execute_command(), {
        "mise",
        "x",
        "node@lts",
        "--",
        "node",
        "--experimental-sqlite",
        stub.custom_server_path,
        "--stdio",
      })
    end)
  end)
  vim.fn.filereadable = original_readable
end

T["get_execute_command()"]["omits sqlite flag for Node 25"] = function()
  setup(stub.valid_node_25, nil, nil, function(err)
    eq(err, nil)
    eq(stub.nodejs.get_execute_command(), { "node", stub.default_server_path, "--stdio" })
  end)
end

T["get_execute_command()"]["supports a string command containing spaces"] = function()
  setup(stub.valid_node_22, "/path to/node", nil, function(err)
    eq(err, nil)
    eq(stub.nodejs.get_execute_command(), {
      "/path to/node",
      "--experimental-sqlite",
      stub.default_server_path,
      "--stdio",
    })
  end)
end

return T
