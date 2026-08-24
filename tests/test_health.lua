local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_health")
local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = child.stop,
  },
})

T["health()"] = MiniTest.new_set()

T["health()"]["reports a configured Node.js command string"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "nodejs"
    config.copilot_node_command = "/custom/node"
    vim.system = function(command)
      M.captured_command = command
      return { wait = function() return { code = 0, stdout = "v22.1.0\n" } end }
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  eq(child.lua([[return M.captured_command]]), { "/custom/node", "--version" })
  u.expect_match(output, "Node%.js command: /custom/node")
  u.expect_match(output, "Node%.js found: 22%.1%.0")
end

T["health()"]["reports a configured Node.js command array"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "nodejs"
    config.copilot_node_command = { "mise", "x", "node@22", "--", "node" }
    vim.system = function(command)
      M.captured_command = command
      return { wait = function() return { code = 0, stdout = "v22.3.0\n" } end }
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  eq(child.lua([[return M.captured_command]]), { "mise", "x", "node@22", "--", "node", "--version" })
  u.expect_match(output, "Node%.js command: mise x node@22 %-%- node")
  u.expect_match(output, "Node%.js found: 22%.3%.0")
end

T["health()"]["rejects a configured Node.js version below 22"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "nodejs"
    config.copilot_node_command = "/custom/node"
    vim.system = function()
      return { wait = function() return { code = 0, stdout = "v20.11.1\n" } end }
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "Node%.js version 22 or newer required but found 20%.11%.1")
end

T["health()"]["reports a configured Node.js command failure"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "nodejs"
    config.copilot_node_command = "/missing/node"
    vim.system = function()
      error("executable not found")
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "Node%.js command: /missing/node")
  u.expect_match(output, "Node%.js command failed")
  u.expect_match(output, "executable not found")
end

T["health()"]["native mode does not report a missing Node.js dependency"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "binary"
    local installer = require("copilot.lsp.installer")
    installer.resolve_target = function() return "linux-x64" end
    installer.ensure = function() error("health check must not download") end
    installer.get_status = function()
      return { state = "ready", target = "linux-x64", path = "/cache/server", error = nil }
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_no_match(output, "`node` not found")
end

T["health()"]["explicit Node.js mode reports the Node.js dependency"] = function()
  child.lua([[require("copilot.config").server.type = "nodejs"]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "Node%.js found")
end

T["health()"]["reports native server resolution and installer status"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "binary"
    local installer = require("copilot.lsp.installer")
    installer.resolve_target = function() return "linux-x64" end
    installer.get_status = function()
      return { state = "downloading", target = "linux-x64", path = nil, error = nil }
    end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "server mode: binary")
  u.expect_match(output, "target: linux%-x64")
  u.expect_match(output, "version: 1%.534%.0")
  u.expect_match(output, "cache: .-copilot%.lua.-lsp")
  u.expect_match(output, "installer state: downloading")
end

T["health()"]["reports custom server paths without resolving a native target"] = function()
  child.lua([[
    local config = require("copilot.config")
    config.server.type = "binary"
    config.server.custom_server_filepath = "/custom/copilot-language-server"
    local installer = require("copilot.lsp.installer")
    installer.resolve_target = function() error("must not resolve custom target") end
  ]])
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "custom server path: /custom/copilot%-language%-server")
  u.expect_match(output, "installation bypassed")
end

T["health()"]["check runs without error when client is running"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

T["health()"]["check runs without error when client is not started"] = function()
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

T["health()"]["reports auth.db as local credentials location"] = function()
  child.configure_copilot()
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "auth%.db")
end

T["health()"]["reports LSP authentication status without requiring a buffer attach"] = function()
  child.configure_copilot()
  child.cmd("checkhealth copilot")

  local output = child.lua([[
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  ]])

  u.expect_match(output, "authentication status: authenticated as `someUser`")
end

T["health()"]["check runs without error when client is disabled"] = function()
  child.lua([[
    local lsp = require("copilot.lsp")
    lsp.setup = function(_, _) return false end
  ]])
  child.lua([[
    M.setup({ filetypes = { ["*"] = true } })
  ]])
  local result = child.lua([[
    local health = require("copilot.health")
    local ok = pcall(health.check)
    return ok
  ]])
  eq(result, true)
end

return T
