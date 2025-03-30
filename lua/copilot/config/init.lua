local logger = require("copilot.logger")

---@class CopilotConfig
---@field panel PanelConfig
---@field suggestion SuggestionConfig
---@field logger LoggerConfig
---@field server ServerConfig
---@field filetypes table<string, boolean> Filetypes to enable Copilot for
---@field auth_provider_url string|nil URL for the authentication provider
---@field workspace_folders string[] Workspace folders to enable Copilot for
---@field server_opts_overrides table<string, any> Options to override for the server
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

  if M.server.custom_server_filepath then
    M.server.custom_server_filepath = vim.fs.normalize(M.server.custom_server_filepath)
  end

  initialized = true
end

return M
