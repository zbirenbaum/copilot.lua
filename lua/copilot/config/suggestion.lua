---@class SuggestionConfig
---@field enabled boolean Whether to enable the suggestion
---@field auto_trigger boolean Whether to trigger the suggestion automatically
---@field hide_during_completion boolean Whether to hide the suggestion during completion
---@field debounce integer Debounce time in milliseconds
---@field keymap SuggestionKeymapConfig Keymap for the suggestion

---@class SuggestionKeymapConfig
---@field accept string|false Keymap for accepting the suggestion
---@field accept_word string|false Keymap for accepting the word
---@field accept_line string|false Keymap for accepting the line
---@field next string|false Keymap for going to the next suggestion
---@field prev string|false Keymap for going to the previous suggestion
---@field dismiss string|false Keymap for dismissing the suggestion

local suggestion = {
  ---@type SuggestionConfig
  default = {
    enabled = true,
    auto_trigger = false,
    hide_during_completion = true,
    debounce = 15,
    keymap = {
      accept = "<M-l>",
      accept_word = false,
      accept_line = false,
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
  },
}

return suggestion
