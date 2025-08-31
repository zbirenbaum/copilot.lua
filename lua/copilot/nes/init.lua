local config = require("copilot.config")
local logger = require("copilot.logger")
local keymaps = require("copilot.keymaps")
local nes_api = require("copilot.nes.api")

local M = {
  initialized = false,
}

---@param goto_end boolean Whether to move the cursor to the end of the accepted suggestion
---@return boolean
local function accept_suggestion(goto_end)
  local result = nes_api.nes_apply_pending_nes()

  if goto_end then
    nes_api.nes_walk_cursor_end_edit()
  end

  return result
end

---@class NesKeymap
local function set_keymap(keymap)
  keymaps.register_keymap_with_passthrough("n", keymap.accept_and_goto, function()
    return accept_suggestion(true)
  end, "[copilot] (nes) accept suggestion and go to end")

  keymaps.register_keymap_with_passthrough("n", keymap.accept, function()
    return accept_suggestion(false)
  end, "[copilot] (nes) accept suggestion")

  keymaps.register_keymap_with_passthrough("n", keymap.dismiss, function()
    return nes_api.nes_clear()
  end, "[copilot] (nes) dismiss suggestion")
end

---@param keymap NesKeymap
local function unset_keymap(keymap)
  keymaps.unset_keymap_if_exists("n", keymap.accept_and_goto)
  keymaps.unset_keymap_if_exists("n", keymap.accept)
  keymaps.unset_keymap_if_exists("n", keymap.dismiss)
end

---@param lsp_client vim.lsp.Client
function M.setup(lsp_client)
  if not config.nes.enabled then
    return
  end

  local au = vim.api.nvim_create_augroup("copilotlsp.init", { clear = true })

  local ok, err = pcall(function()
    nes_api.nes_lsp_on_init(lsp_client, au)
  end)

  if ok then
    logger.info("copilot-lsp nes loaded")
  else
    logger.error("copilot-lsp nes failed to load:", err)
  end

  set_keymap(config.nes.keymap)
  M.initialized = true
end

function M.teardown()
  if not M.initialized then
    return
  end

  unset_keymap(config.nes.keymap)
end

return M
