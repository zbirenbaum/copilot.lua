local reference_screenshot = MiniTest.expect.reference_screenshot
local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_util")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
      child.bo.readonly = false
    end,
    post_once = child.stop,
  },
})

T["util()"] = MiniTest.new_set()

T["util()"]["passthrough Esc passes original keymap"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })]])

  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456")
  child.wait_for_suggestion()

  reference_screenshot(child.get_screenshot(), nil, { ignore_text = { 9, 10 }, ignore_attr = { 9, 10 } })
end

-- get_editor_info tests

T["util()"]["get_editor_info returns Neovim name and version"] = function()
  local info = child.lua([[
    local util = require("copilot.util")
    local info = util.get_editor_info()
    return info
  ]])
  eq(info.editorInfo.name, "Neovim")
  eq(type(info.editorInfo.version), "string")
  eq(info.editorPluginInfo.name, "copilot.lua")
  eq(info.editorPluginInfo.version, "1.430.0")
end

-- strutf16len tests

T["util()"]["strutf16len ASCII string"] = function()
  local len = child.lua([[
    local util = require("copilot.util")
    return util.strutf16len("hello")
  ]])
  eq(len, 5)
end

T["util()"]["strutf16len empty string"] = function()
  local len = child.lua([[
    local util = require("copilot.util")
    return util.strutf16len("")
  ]])
  eq(len, 0)
end

-- append_command tests

T["util()"]["append_command string + string"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.append_command("node", "--stdio")
  ]])
  eq(result, { "node", "--stdio" })
end

T["util()"]["append_command table + table"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.append_command({"node", "--flag"}, {"--stdio", "--verbose"})
  ]])
  eq(result, { "node", "--flag", "--stdio", "--verbose" })
end

T["util()"]["append_command string + table"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.append_command("node", {"--stdio", "--verbose"})
  ]])
  eq(result, { "node", "--stdio", "--verbose" })
end

T["util()"]["append_command table + string"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.append_command({"node", "--flag"}, "--stdio")
  ]])
  eq(result, { "node", "--flag", "--stdio" })
end

T["util()"]["append_command filters nil values in tables"] = function()
  -- In Lua, ipairs stops at the first nil hole in a sequence,
  -- so {1, nil, 3} only iterates over index 1.
  -- The nil filtering in append_command handles explicit nil checks.
  local result = child.lua([[
    local util = require("copilot.util")
    local t = {"a"}
    t[3] = "b"
    return util.append_command(t, {"c"})
  ]])
  -- ipairs stops at first nil hole, so only "a" from cmd, then "c" from append
  eq(result, { "a", "c" })
end

-- get_node_args tests

T["util()"]["get_node_args includes --experimental-sqlite for node < 25"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.get_node_args("/path/to/server.js", "nodejs", "22.1.0")
  ]])
  eq(result, { "--experimental-sqlite", "/path/to/server.js", "--stdio" })
end

T["util()"]["get_node_args excludes --experimental-sqlite for node >= 25"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.get_node_args("/path/to/server.js", "nodejs", "25.0.0")
  ]])
  eq(result, { "/path/to/server.js", "--stdio" })
end

T["util()"]["get_node_args nil version defaults to including flag"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.get_node_args("/path/to/server.js", "nodejs", nil)
  ]])
  eq(result, { "--experimental-sqlite", "/path/to/server.js", "--stdio" })
end

T["util()"]["get_node_args binary type excludes --experimental-sqlite"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.get_node_args("/path/to/server", "binary", "22.1.0")
  ]])
  eq(result, { "/path/to/server", "--stdio" })
end

-- buffer attach status tests

T["util()"]["buffer attach status get/set roundtrip"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    local buf = vim.api.nvim_get_current_buf()
    util.set_buffer_attach_status(buf, "attached")
    return util.get_buffer_attach_status(buf)
  ]])
  eq(result, "attached")
end

T["util()"]["buffer attach status default for missing var"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    local buf = vim.api.nvim_create_buf(false, true)
    return util.get_buffer_attach_status(buf)
  ]])
  eq(result, "attach not yet requested")
end

-- buffer previous ft tests

T["util()"]["buffer previous ft get/set roundtrip"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    local buf = vim.api.nvim_get_current_buf()
    util.set_buffer_previous_ft(buf, "lua")
    return util.get_buffer_previous_ft(buf)
  ]])
  eq(result, "lua")
end

T["util()"]["buffer previous ft nil for missing var"] = function()
  local result = child.lua([[
    local util = require("copilot.util")
    local buf = vim.api.nvim_create_buf(false, true)
    local ft = util.get_buffer_previous_ft(buf)
    if ft == nil then return "nil_value" end
    return ft
  ]])
  eq(result, "nil_value")
end

-- should_attach tests

T["util()"]["should_attach returns false for invalid buffer"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local util = require("copilot.util")
    return util.should_attach(99999)
  ]])
  eq(result, false)
end

T["util()"]["should_attach returns true for valid buffer"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local util = require("copilot.util")
    local buf = vim.api.nvim_get_current_buf()
    return util.should_attach(buf)
  ]])
  eq(result, true)
end

return T
