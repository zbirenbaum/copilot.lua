local utils = require("copilot.panel.utils")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function() end,
  },
})

T["panel_utils()"] = MiniTest.new_set()

T["panel_utils()"]["is_panel_uri returns true for copilot:// prefix"] = function()
  eq(utils.is_panel_uri("copilot:///home/user/file.lua"), true)
end

T["panel_utils()"]["is_panel_uri returns false for non-copilot URIs"] = function()
  eq(utils.is_panel_uri("file:///home/user/file.lua"), false)
  eq(utils.is_panel_uri("/home/user/file.lua"), false)
  eq(utils.is_panel_uri(""), false)
end

T["panel_utils()"]["panel_uri_to_doc_uri replaces copilot with file"] = function()
  local doc_uri = utils.panel_uri_to_doc_uri("copilot:///home/user/file.lua")
  eq(doc_uri, "file:///home/user/file.lua")
end

T["panel_utils()"]["panel_uri_from_doc_uri creates copilot URI"] = function()
  local panel_uri = utils.panel_uri_from_doc_uri("file:///home/user/file.lua")
  eq(utils.is_panel_uri(panel_uri), true)
  -- The URI should start with copilot://
  eq(panel_uri:sub(1, 10), "copilot://")
end

T["panel_utils()"]["roundtrip preserves path structure"] = function()
  local original_doc_uri = "file:///home/user/project/file.lua"
  local panel_uri = utils.panel_uri_from_doc_uri(original_doc_uri)
  local restored_doc_uri = utils.panel_uri_to_doc_uri(panel_uri)
  -- After roundtrip, should get back a file:// URI with the same path
  eq(restored_doc_uri:sub(1, 7), "file://")
  -- The path portion should contain the original filename
  local has_file = restored_doc_uri:find("file.lua") ~= nil
  eq(has_file, true)
end

return T
