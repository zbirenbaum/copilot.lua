-- Abstraction to the copilot-lsp module

local M = {}

function M.nes_set_auto_trigger(value)
  local config = require("copilot-lsp.config")
  config.config.require("copilot-lsp.nes").auto_trigger = value
end

function M.nes_lsp_on_init(client, au)
  require("copilot-lsp.nes").lsp_on_init(client, au)
end

function M.set_hl()
  local util = require("copilot-lsp.util")
  util.set_hl()
end

---@param bufnr? integer
---@return boolean --if the cursor walked
function M.nes_walk_cursor_start_edit(bufnr)
  return require("copilot-lsp.nes").walk_cursor_start_edit(bufnr)
end

---@param bufnr? integer
---@return boolean --if the cursor walked
function M.nes_walk_cursor_end_edit(bufnr)
  return require("copilot-lsp.nes").walk_cursor_end_edit(bufnr)
end

---@param bufnr? integer
---@return boolean --if the nes was applied
function M.nes_apply_pending_nes(bufnr)
  return require("copilot-lsp.nes").apply_pending_nes(bufnr)
end

---@return boolean -- true if a suggestion was cleared, false if no suggestion existed
function M.nes_clear()
  return require("copilot-lsp.nes").clear()
end

function M.test()
  require("copilot-lsp.nes")
end

return M
