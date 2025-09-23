local logger = require("copilot.logger")

local M = {}
local previous_keymaps = {}

---@param bufnr integer
---@param mode string
---@param key string
local function get_keymap_key(bufnr, mode, key)
  if not bufnr or not mode or not key then
    logger.error("Invalid parameters to get_keymap_key" .. vim.inspect({ bufnr, mode, key }))
    return "invalid"
  end

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

  local keymap_key = get_keymap_key(bufnr, mode, key)
  if previous_keymaps[keymap_key] then
    logger.trace("Keymap already registered for " .. keymap_key)
    return
  end

  vim.keymap.set(mode, key, function()
    action()
  end, {
    desc = desc,
    silent = true,
    buffer = bufnr,
  })

  previous_keymaps[keymap_key] = { type = "none", value = nil }
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
  if not key or not bufnr then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_del_keymap, bufnr, mode, key)
  previous_keymaps[get_keymap_key(bufnr, mode, key)] = nil

  if not ok then
    logger.error("Could not unset keymap for " .. (mode or "nil") .. " " .. key .. ", bufnr " .. bufnr .. ": " .. err)
  end
end

---@param config CopilotConfig
function M.validate(config)
  local suggestion_keymaps = config.suggestion.keymap or {}
  local nes_keymaps = config.nes.keymap or {}
  local panel_keymaps = config.panel.keymap or {}
  local seen = {}
  local duplicates = {}

  for _, cfg in ipairs({ suggestion_keymaps, nes_keymaps, panel_keymaps }) do
    for action, km in pairs(cfg) do
      if not km then
        goto continue
      end

      -- TODO: find a better way to determine mode, this is prone to maintenance bugs
      -- TODO: Not sure how to validate keymaps, since some COULD be duplicates and valid
      local mode = (action == config.panel.keymap.open or vim.tbl_contains(config.nes.keymap, action)) and "n" or "i"
      local keymap_key = get_keymap_key(0, mode, km)
      if seen[keymap_key] then
        duplicates[keymap_key] = (duplicates[keymap_key] or 1) + 1
      else
        seen[keymap_key] = true
      end

      ::continue::
    end
  end

  for key, count in pairs(duplicates) do
    logger.error("Duplicate keymap detected: " .. key .. " (" .. count .. " times), please review your configuration.")
  end
end

return M
