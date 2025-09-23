local logger = require("copilot.logger")
local config = require("copilot.config")

local M = {}
local previous_keymaps = {}

local function get_keymap_key(bufnr, mode, key)
  return bufnr .. ":" .. mode .. ":" .. key
end
---@param mode string
---@param key string
---@param action function
---@param desc string
---@param bufnr integer
function M.register_keymap(mode, key, action, desc, bufnr)
  if not key then
    return
  end

  if not mode or not action then
    logger.error("Invalid parameters to register_keymap" .. vim.inspect({ mode, key, action, desc, bufnr }))
    return
  end

  vim.keymap.set(mode, key, function()
    action()
  end, {
    desc = desc,
    silent = true,
    buffer = bufnr,
  })

  previous_keymaps[get_keymap_key(bufnr, mode, key)] = { type = "none", value = nil }
end

---@param mode string
---@param key string
---@param action function: boolean
---@param desc string
---@param bufnr integer
function M.register_keymap_with_passthrough(mode, key, action, desc, bufnr)
  if not key then
    return
  end

  if not mode or not action then
    logger.error("Invalid parameters to register_keymap_with_passthrough" .. vim.inspect({ mode, key, action, desc }))
    return
  end

  local keymap_key = get_keymap_key(bufnr, mode, key)

  if previous_keymaps[keymap_key] then
    logger.trace("Keymap already registered for " .. keymap_key)
    return
  end

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
      previous_keymaps[keymap_key] = { type = "none", value = nil }
      logger.trace("No existing keymap for " .. keymap_key)
    end
  else
    previous_keymaps[keymap_key] = { type = "none", value = nil }
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
          return "<Ignore>"
        elseif prev.type == "callback" then
          logger.trace("Passing through to previous keymap callback for " .. keymap_key)
          prev.value()
          return "<Ignore>"
        end
      end
      logger.trace("No previous keymap to pass through for " .. keymap_key)

      return key
    end
  end, {
    desc = desc,
    expr = true,
    silent = true,
    buffer = bufnr,
  })
end

---@param mode string
---@param key string|false
---@param bufnr integer
function M.unset_keymap_if_exists(mode, key, bufnr)
  if not key then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_del_keymap, bufnr, mode, key)
  previous_keymaps[get_keymap_key(bufnr, mode, key)] = nil

  if not ok then
    local suggestion_keymaps = config.suggestion.keymap or {}
    local nes_keymaps = config.nes.keymap or {}
    local panel_keymaps = config.panel.keymap or {}
    local found = false

    for _, tbl in ipairs({ suggestion_keymaps, nes_keymaps, panel_keymaps }) do
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

    logger.error("Could not unset keymap for " .. mode .. " " .. key .. ", bufnr " .. bufnr .. ": " .. err)
  end
end

return M
