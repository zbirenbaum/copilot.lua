local logger = require("copilot.logger")

---@class copilot_config
local default_config = {
  ---@class copilot_config_panel
  panel = {
    enabled = true,
    auto_refresh = false,
    ---@type table<'jump_prev'|'jump_next'|'accept'|'refresh'|'open', false|string>
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
  ---@class copilot_config_suggestion
  suggestion = {
    enabled = true,
    auto_trigger = false,
    hide_during_completion = true,
    debounce = 15,
    ---@type table<'accept'|'accept_word'|'accept_line'|'next'|'prev'|'dismiss', false|string>
    keymap = {
      accept = "<M-l>",
      accept_word = false,
      accept_line = false,
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
  },
  ---@class copilot_config_logging
  logger = {
    log_to_file = false,
    file = vim.fn.stdpath("log") .. "/copilot-lua.log",
    file_log_level = vim.log.levels.WARN,
    print_log = true,
    print_log_level = vim.log.levels.WARN,
    ---@type string<'off'|'messages'|'verbose'>
    trace_lsp = "off",
    trace_lsp_progress = false,
  },
  ---@deprecated
  ft_disable = nil,
  ---@type table<string, boolean>
  filetypes = {},
  ---@type string|nil
  auth_provider_url = nil,
  copilot_node_command = "node",
  ---@type string[]
  workspace_folders = {},
  server_opts_overrides = {},
  ---@type string|nil
  copilot_model = nil,
  ---@type function
  get_root_dir = function()
    vim.fs.dirname(vim.fs.find(".git", { path = ".", upward = true })[1])
  end,
}

local mod = {
  ---@type copilot_config
  config = nil,
}

function mod.setup(opts)
  if mod.config then
    logger.warn("config is already set")
    return mod.config
  end

  local config = vim.tbl_deep_extend("force", default_config, opts or {})

  --- for backward compatibility
  if config.ft_disable then
    for _, disabled_ft in ipairs(config.ft_disable) do
      config.filetypes[disabled_ft] = false
    end

    config.ft_disable = nil
  end

  mod.config = config

  return mod.config
end

---@param key? string
function mod.get(key)
  if not mod.config then
    logger.error("not initialized")
    return
  end

  if key then
    return mod.config[key]
  end

  return mod.config
end

---@param key string
---@param value any
function mod.set(key, value)
  if not mod.config then
    logger.error("not initialized")
    return
  end

  mod.config[key] = value
end

return mod
