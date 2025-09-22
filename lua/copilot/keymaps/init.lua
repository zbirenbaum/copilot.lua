local logger = require("copilot.logger")
local config = require("copilot.config")

local M = {}
local previous_keymaps = {}

---@param mode string
---@param key string
---@param action function
---@param desc string
function M.register_keymap(mode, key, action, desc)
  if not key then
    return
  end

  if not mode or not action then
    logger.error("Invalid parameters to register_keymap" .. vim.inspect({ mode, key, action, desc }))
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
  if not key then
    return
  end

  if not mode or not action then
    logger.error("Invalid parameters to register_keymap_with_passthrough" .. vim.inspect({ mode, key, action, desc }))
    return
  end

  local keymap_key = mode .. ":" .. key
  -- Save any existing mapping for this key
  local existing = vim.fn.maparg(key, mode, false, true)
  if existing then
    if existing.rhs and existing.rhs ~= "" then
      previous_keymaps[keymap_key] = { type = "rhs", value = existing.rhs }
      logger.trace("Saved existing keymap for " .. keymap_key .. ": " .. existing.rhs)
    elseif existing.callback then
      previous_keymaps[keymap_key] = { type = "callback", value = existing.callback }
      logger.trace("Saved existing keymap callback for " .. keymap_key)
    else
      previous_keymaps[keymap_key] = nil
      logger.trace("No existing keymap for " .. keymap_key)
    end
  else
    previous_keymaps[keymap_key] = nil
    logger.trace("No existing keymap for " .. keymap_key)
  end

  vim.keymap.set(mode, key, function()
    logger.trace("Keymap triggered for " .. keymap_key)

    if action() then
      logger.trace("Action handled the keymap for " .. keymap_key)
      return "<Ignore>"
    else
      local prev = previous_keymaps[keymap_key]

      if prev then
        if prev.type == "rhs" then
          logger.trace("Passing through to previous keymap for " .. keymap_key .. ": " .. prev.value)
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev.value, true, false, true), mode, true)
        elseif prev.type == "callback" then
          logger.trace("Passing through to previous keymap callback for " .. keymap_key)
          prev.value()
        end
        return "<Ignore>"
      end
      logger.trace("No previous keymap to pass through for " .. keymap_key)

      return key
    end
  end, {
    desc = desc,
    expr = true,
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
