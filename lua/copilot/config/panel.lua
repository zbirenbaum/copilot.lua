---@class (exact) PanelConfig
---@field enabled boolean Whether to enable the panel
---@field auto_refresh boolean Whether to automatically refresh the panel
---@field keymap PanelKeymapConfig Keymap for the panel
---@field layout PanelLayoutConfig Layout of the panel

---@class (exact) PanelKeymapConfig
---@field jump_prev string|false Keymap for jumping to the previous suggestion
---@field jump_next string|false Keymap for jumping to the next suggestion
---@field accept string|false Keymap for accepting the suggestion
---@field refresh string|false Keymap for refreshing the suggestion
---@field open string|false Keymap for opening the suggestion

---@class (exact) PanelLayoutConfig
---@field position string<'left'|'right'|'top'|'bottom'> Position of the panel
---@field ratio number Ratio of the panel size, between 0 and 1

local panel = {
  ---@type PanelConfig
  default = {
    enabled = true,
    auto_refresh = false,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<M-CR>",
    },
    layout = {
      position = "bottom",
      ratio = 0.4,
    },
  },
}

---@param config PanelConfig
function panel.validate(config)
  vim.validate("enabled", config.enabled, "boolean")
  vim.validate("auto_refresh", config.auto_refresh, "boolean")
  vim.validate("keymap", config.keymap, "table")
  vim.validate("layout", config.layout, "table")
  vim.validate("keymap.jump_prev", config.keymap.jump_prev, { "string", "boolean" })
  vim.validate("keymap.jump_next", config.keymap.jump_next, { "string", "boolean" })
  vim.validate("keymap.accept", config.keymap.accept, { "string", "boolean" })
  vim.validate("keymap.refresh", config.keymap.refresh, { "string", "boolean" })
  vim.validate("keymap.open", config.keymap.open, { "string", "boolean" })
  vim.validate("layout.position", config.layout.position, function(value)
    return value == "left" or value == "right" or value == "top" or value == "bottom"
  end, false, "left, right, top or bottom")
  vim.validate("layout.ratio", config.layout.ratio, function(value)
    return type(value) == "number" and value >= 0 and value <= 1
  end, false, "number between 0 and 1")
end

return panel
