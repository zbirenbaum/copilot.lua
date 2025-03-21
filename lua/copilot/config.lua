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
  ---@type function|string
  root_dir = function()
    return vim.fs.dirname(vim.fs.find(".git", { upward = true })[1])
  end,
}

local mod = {
  config = nil,
}

function mod.setup(opts)
  if mod.config then
    vim.notify("[Copilot] config is already set", vim.log.levels.WARN)
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
    error("[Copilot] not initialized")
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
    error("[Copilot] not initialized")
  end

  mod.config[key] = value
end

function mod.get_root_dir()
  if not mod.config then
    error("[Copilot] not initialized")
  end

  local config_root_dir = mod.config.root_dir
  local root_dir --[[@as string]]

  if type(config_root_dir) == "function" then
    root_dir = config_root_dir()
  else
    root_dir = config_root_dir
  end

  if not root_dir or root_dir == "" then
    root_dir = "."
  end

  root_dir = vim.fn.fnamemodify(root_dir, ":p:h")
  return root_dir
end

return mod
