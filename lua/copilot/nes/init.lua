local config = require("copilot.config")
local logger = require("copilot.logger")
local util = require("copilot.util")

local M = {
  initialized = false,
}

---@param goto_end boolean Whether to move the cursor to the end of the accepted suggestion
local function accept_suggestion(goto_end)
  local nes_api = require("copilot-lsp.api")
  nes_api.nes_apply_pending_nes()

  if goto_end then
    nes_api.nes_walk_cursor_end_edit()
  end
end

---@class NesKeymap
local function set_keymap(keymap)
  if keymap.accept_and_goto then
    vim.keymap.set("n", keymap.accept_and_goto, function()
      accept_suggestion(true)
    end, {
      desc = "[copilot] (nes) accept suggestion and go to end",
      silent = true,
    })
  end

  if keymap.accept then
    vim.keymap.set("n", keymap.accept, function()
      accept_suggestion(false)
    end, {
      desc = "[copilot] (nes) accept suggestion",
      silent = true,
    })
  end

  if keymap.dismiss then
    vim.keymap.set("n", keymap.dismiss, function()
      require("copilot-lsp.api").nes_clear()
    end, {
      desc = "[copilot] (nes) dismiss suggestion",
      silent = true,
    })
  end
end

---@param keymap NesKeymap
local function unset_keymap(keymap)
  util.unset_keymap_if_exists("n", keymap.accept_and_goto)
  util.unset_keymap_if_exists("n", keymap.accept)
  util.unset_keymap_if_exists("n", keymap.dismiss)
end

---@param lsp_client vim.lsp.Client
function M.setup(lsp_client)
  if not config.nes.enabled then
    return
  end

  local au = vim.api.nvim_create_augroup("copilotlsp.init", { clear = true })

  local ok, err = pcall(function()
    require("copilot-lsp.api").nes_lsp_on_init(lsp_client, au)
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
