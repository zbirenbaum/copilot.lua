local logger = require("copilot.logger")
local nes_api = require("copilot.nes.api")
---@class NesKeymap
---@field accept_and_goto string|false Keymap to accept the suggestion and go to the end of the suggestion
---@field accept string|false Keymap to accept the suggestion
---@field dismiss string|false Keymap to dismiss the suggestion

---@class NesConfig
---@field enabled boolean Whether to enable nes (next edit suggestions)
---@field auto_trigger boolean Whether to automatically trigger next edit suggestions
---@field keymap NesKeymap Keymaps for nes actions

local M = {
  ---@type NesConfig
  default = {
    enabled = false,
    auto_trigger = false,
    keymap = {
      accept_and_goto = false,
      accept = false,
      dismiss = false,
    },
  },
}

---@type NesConfig
M.config = vim.deepcopy(M.default)

---@param opts? NesConfig
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.default, opts)
end

---@param config NesConfig
function M.validate(config)
  vim.validate("enabled", config.enabled, "boolean")
  vim.validate("auto_trigger", config.auto_trigger, "boolean")
  vim.validate("keymap", config.keymap, "table")
  vim.validate("keymap.accept_and_goto", config.keymap.accept_and_goto, { "string", "boolean" })
  vim.validate("keymap.accept", config.keymap.accept, { "string", "boolean" })
  vim.validate("keymap.dismiss", config.keymap.dismiss, { "string", "boolean" })

  if config.enabled then
    local has_nes, _ = pcall(function()
      nes_api.test()
    end)

    if not has_nes then
      logger.error(
        "copilot-lsp is not available, disabling nes.\nPlease refer to the documentation and ensure it is installed."
      )
      config.enabled = false
    end
  end
end

return M
