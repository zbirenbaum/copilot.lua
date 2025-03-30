---@class PanelConfig
---@field enabled boolean Whether to enable the panel
---@field auto_refresh boolean Whether to automatically refresh the panel
---@field keymap PanelKeymapConfig Keymap for the panel
---@field layout config_panel_layout Layout of the panel

---@class PanelKeymapConfig
---@field jump_prev string|false Keymap for jumping to the previous suggestion
---@field jump_next string|false Keymap for jumping to the next suggestion
---@field accept string|false Keymap for accepting the suggestion
---@field refresh string|false Keymap for refreshing the suggestion
---@field open string|false Keymap for opening the suggestion

---@class config_panel_layout
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

return panel
