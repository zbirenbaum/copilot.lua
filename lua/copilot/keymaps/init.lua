local logger = require("copilot.logger")
local config = require("copilot.config")

local M = {}

local previous_keymaps = {}

---@param mode string
---@param key string
---@param action function
---@param desc string
function M.register_keymap(mode, key, action, desc)
  if not mode or not key or not action then
    return
  end

  vim.keymap.set(mode, key, function()
    action()
  end, {
    desc = desc,
    silent = true,
  })
end

---@param mode string
---@param key string
---@param action function: boolean
---@param desc string
function M.register_keymap_with_passthrough(mode, key, action, desc)
  if not mode or not key or not action then
    return
  end

  local keymap_key = mode .. ":" .. key
  -- Save any existing mapping for this key
  local existing = vim.fn.maparg(key, mode, false, true)
  if existing and existing.rhs and existing.rhs ~= "" then
    previous_keymaps[keymap_key] = existing.rhs
  else
    previous_keymaps[keymap_key] = nil
  end

  vim.keymap.set(mode, key, function()
    local action_ran = action()
    if not action_ran then
      -- If there was a previous mapping, execute it
      local prev = previous_keymaps[keymap_key]
      if prev then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev, true, false, true), mode, true)
      end
    end
  end, {
    desc = desc,
    silent = true,
  })
end

---@param mode string
---@param key string|false
function M.unset_keymap_if_exists(mode, key)
  if not key then
    return
  end

  local ok, err = pcall(vim.api.nvim_del_keymap, mode, key)

  if not ok then
    local suggestion_keymaps = config.suggestion.keymap or {}
    local panel_keymaps = config.panel.keymap or {}
    local found = false

    for _, tbl in ipairs({ suggestion_keymaps, panel_keymaps }) do
      for _, v in pairs(tbl) do
        if v == key then
          if found then
            logger.error("Keymap " .. key .. " is used for two different actions, please review your configuration.")
            return
          else
            found = true
          end
        end
      end
    end

    logger.error("Could not unset keymap for " .. mode .. " " .. key .. ": " .. err)
  end
end

return M
