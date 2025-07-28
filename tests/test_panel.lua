local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_panel")
local utils = require("copilot.panel.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case()
      child.bo.readonly = false
      child.lua("p = require('copilot.panel')")
    end,
    post_once = child.stop,
  },
})

T["panel()"] = MiniTest.new_set()

T["panel()"]["panel suggestions works"] = function()
  child.o.lines, child.o.columns = 30, 100
  child.config.panel = child.config.panel .. "auto_refresh = true,"
  child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
  child.configure_copilot()
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.lua("p.toggle()")
  child.wait_for_panel_suggestion()

  local lines = child.lua([[
    return vim.api.nvim_buf_get_lines(2, 4, 5, false)
  ]])

  -- For Windows, on some shells not all
  if lines[1] == "789\r" then
    lines[1] = "789"
  end

  eq(lines[1], "789")
end

-- Disabled for now as unnamed buffers have issues with not having a URI
-- T["panel()"]["panel suggestion accept works"] = function()
--   child.o.lines, child.o.columns = 30, 100
--   child.config.panel = child.config.panel .. "auto_refresh = true,"
--   child.config.suggestion = child.config.suggestion .. "auto_trigger = true,"
--   child.configure_copilot()
--   child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
--   child.lua("p.toggle()")
--   child.wait_for_panel_suggestion()
--   child.cmd("buffer 2")
--   child.type_keys("4gg")
--   child.lua("p.accept()")
--   child.cmd("buffer 1")
--   reference_screenshot(child.get_screenshot())
-- end

T["panel.utils()"] = MiniTest.new_set()

T["panel.utils()"]["panel_uri_from_doc_uri"] = function()
  local panel_uri = ""

  if vim.fn.has("win32") > 0 then
    panel_uri = "copilot:///C:/Users/antoi/AppData/Local/nvim-data/lazy/copilot.lua/lua/copilot/suggestion/init.lua"
  else
    panel_uri = "copilot:///home/antoi/test.lua"
  end

  local doc_uri = utils.panel_uri_to_doc_uri(panel_uri)

  if vim.fn.has("win32") > 0 then
    eq(doc_uri, "file:///C:/Users/antoi/AppData/Local/nvim-data/lazy/copilot.lua/lua/copilot/suggestion/init.lua")
  else
    eq(doc_uri, "file:///home/antoi/test.lua")
  end
end

T["panel.utils()"]["panel_uri_to_doc_uri"] = function()
  local doc_uri = ""

  if vim.fn.has("win32") > 0 then
    doc_uri = "file:///C:/Users/antoi/AppData/Local/nvim-data/lazy/copilot.lua/lua/copilot/suggestion/init.lua"
  else
    doc_uri = "file:///home/antoi/test.lua"
  end

  local panel_uri = utils.panel_uri_from_doc_uri(doc_uri)

  -- Windows result
  if vim.fn.has("win32") > 0 then
    eq(panel_uri, "copilot:///C:/Users/antoi/AppData/Local/nvim-data/lazy/copilot.lua/lua/copilot/suggestion/init.lua")
  else
    eq(panel_uri, "copilot:///home/antoi/test.lua")
  end
end

return T
