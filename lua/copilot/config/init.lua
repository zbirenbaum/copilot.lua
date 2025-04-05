local logger = require("copilot.logger")

---@class CopilotConfig
---@field panel PanelConfig
---@field suggestion SuggestionConfig
---@field logger LoggerConfig
---@field server ServerConfig
---@field filetypes table<string, boolean> Filetypes to enable Copilot for
---@field auth_provider_url string|nil URL for the authentication provider
---@field workspace_folders string[] Workspace folders to enable Copilot for
---@field server_opts_overrides? table<string, any> Options to override for the server
---@field copilot_model string|nil Model to use for Copilot, LSP server dictates the default
---@field root_dir RootDirFuncOrString Root directory for the project, defaults to the nearest .git directory
---@field should_attach ShouldAttachFunc Function to determine if Copilot should attach to the buffer
---@field copilot_node_command string Path to the Node.js executable, defaults to "node"

local initialized = false

---@class CopilotConfig
local M = {
  panel = require("copilot.config.panel").default,
  suggestion = require("copilot.config.suggestion").default,
  logger = require("copilot.config.logger").default,
  server = require("copilot.config.server").default,
  root_dir = require("copilot.config.root_dir").default,
  should_attach = require("copilot.config.should_attach").default,
  filetypes = {},
  auth_provider_url = nil,
  workspace_folders = {},
  server_opts_overrides = {},
  copilot_model = nil,
  copilot_node_command = "node",
}

---@param user_configs CopilotConfig
function M.merge_with_user_configs(user_configs)
  logger.trace("setting up configuration, opts", user_configs)

  if initialized then
    logger.warn("config is already set")
    return
  end

  local merged = vim.tbl_deep_extend("force", M, user_configs or {})
  for k, v in pairs(merged) do
    M[k] = v
  end

  if vim.fn.has("nvim-0.11") == 1 then
    M.validate(M)
  end

  initialized = true
end

---@param config CopilotConfig
function M.validate(config)
  vim.validate("panel", config.panel, "table")
  vim.validate("suggestion", config.suggestion, "table")
  vim.validate("logger", config.logger, "table")
  vim.validate("server", config.server, "table")
  vim.validate("filetypes", config.filetypes, "table")
  vim.validate("auth_provider_url", config.auth_provider_url, { "string", "nil" })
  vim.validate("workspace_folders", config.workspace_folders, "table")
  vim.validate("server_opts_overrides", config.server_opts_overrides, "table", true)
  vim.validate("copilot_model", config.copilot_model, { "string", "nil" })
  vim.validate("root_dir", config.root_dir, { "string", "function" })
  vim.validate("should_attach", config.should_attach, "function")
  vim.validate("copilot_node_command", config.copilot_node_command, "string")

  require("copilot.config.panel").validate(config.panel)
  require("copilot.config.suggestion").validate(config.suggestion)
  require("copilot.config.logger").validate(config.logger)
  require("copilot.config.server").validate(config.server)
  require("copilot.config.root_dir").validate(config.root_dir)
  require("copilot.config.should_attach").validate(config.should_attach)
end

return M
