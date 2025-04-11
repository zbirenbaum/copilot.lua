---@alias SuggestionNotification fun(virtual_text: {}, virtual_lines: {})

---@class (exact) SuggestionConfig
---@field enabled boolean Whether to enable the suggestion
---@field auto_trigger boolean Whether to trigger the suggestion automatically
---@field hide_during_completion boolean Whether to hide the suggestion during completion
---@field debounce integer Debounce time in milliseconds
---@field trigger_on_accept boolean To either trigger the suggestion on accept or pass the keystroke to the buffer
---@field suggestion_notification SuggestionNotification|nil Callback function whenever a suggestion is triggered
---@field keymap SuggestionKeymapConfig Keymap for the suggestion

---@class (exact) SuggestionKeymapConfig
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
    trigger_on_accept = true,
    suggestion_notification = nil,
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

function suggestion.validate(config)
  vim.validate("enabled", config.enabled, "boolean")
  vim.validate("auto_trigger", config.auto_trigger, "boolean")
  vim.validate("hide_during_completion", config.hide_during_completion, "boolean")
  vim.validate("debounce", config.debounce, { "number", "nil" })
  vim.validate("trigger_on_accept", config.trigger_on_accept, "boolean")
  vim.validate("suggestion_notification", config.suggestion_notification, { "function", "nil" })
  vim.validate("keymap", config.keymap, "table")
  vim.validate("keymap.accept", config.keymap.accept, { "string", "boolean" })
  vim.validate("keymap.accept_word", config.keymap.accept_word, { "string", "boolean" })
  vim.validate("keymap.accept_line", config.keymap.accept_line, { "string", "boolean" })
  vim.validate("keymap.next", config.keymap.next, { "string", "boolean" })
  vim.validate("keymap.prev", config.keymap.prev, { "string", "boolean" })
  vim.validate("keymap.dismiss", config.keymap.dismiss, { "string", "boolean" })
end

return suggestion
