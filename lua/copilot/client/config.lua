local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local lsp = require("copilot.lsp")
local utils = require("copilot.client.utils")
local M = {}

---@type table<fun(client:table)>
local callbacks = {}

---@param overrides table<string, any>
---@param client CopilotClient
function M.prepare_client_config(overrides, client)
  if lsp.binary.initialization_failed then
    client.startup_error = "initialization of copilot-language-server failed"
    return
  end

  client.startup_error = nil

  local cmd = lsp.get_execute_command()

  if not cmd then
    logger.error("copilot server type not supported")
    return
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.window.showDocument.support = true

  capabilities.workspace = {
    workspaceFolders = true,
  }

  local root_dir = utils.get_root_dir(config.root_dir)
  local workspace_folders = {
    --- @type workspace_folder
    {
      uri = vim.uri_from_fname(root_dir),
      -- important to keep root_dir as-is for the name as lsp.lua uses this to check the workspace has not changed
      name = root_dir,
    },
  }

  local config_workspace_folders = config.workspace_folders

  for _, config_workspace_folder in ipairs(config_workspace_folders) do
    if config_workspace_folder ~= "" then
      table.insert(
        workspace_folders,
        --- @type workspace_folder
        {
          uri = vim.uri_from_fname(config_workspace_folder),
          name = config_workspace_folder,
        }
      )
    end
  end

  local editor_info = util.get_editor_info()
  local provider_url = config.auth_provider_url
  local proxy_uri = vim.g.copilot_proxy

  local settings = { ---@type copilot_settings
    telemetry = { ---@type github_settings_telemetry
      telemetryLevel = "all",
    },
  }

  if proxy_uri then
    settings = vim.tbl_extend("force", settings, {
      http = { ---@type copilot_settings_http
        proxy = proxy_uri,
        proxyStrictSSL = vim.g.copilot_proxy_strict_ssl or false,
        proxyKerberosServicePrincipal = nil,
      },
    })
  end

  if provider_url then
    settings = vim.tbl_extend("force", settings, {
      ["github-enterprise"] = { ---@type copilot_settings_github-enterprise
        uri = provider_url,
      },
    })
  end

  -- LSP config, not to be confused with config.lua
  return vim.tbl_deep_extend("force", {
    cmd = cmd,
    root_dir = root_dir,
    name = "copilot",
    capabilities = capabilities,
    get_language_id = function(_, filetype)
      return require("copilot.client.filetypes").language_for_file_type(filetype)
    end,
    on_init = function(lsp_client, initialize_result)
      if client.id == lsp_client.id then
        client.capabilities = initialize_result.capabilities
      end

      vim.schedule(function()
        local configurations = utils.get_workspace_configurations()
        api.notify_change_configuration(lsp_client, configurations)
        logger.trace("workspace configuration", configurations)

        -- to activate tracing if we want it
        local logger_conf = config.logger
        local trace_params = { value = logger_conf.trace_lsp } --[[@as copilot_nofify_set_trace_params]]
        api.notify_set_trace(lsp_client, trace_params)

        -- prevent requests to copilot prior to being initialized
        client.initialized = true

        for _, callback in ipairs(callbacks) do
          callback(lsp_client)
        end
      end)
    end,
    on_exit = function(code, _, client_id)
      if client.id == client_id then
        vim.schedule(function()
          client.teardown()
          client.id = nil
          client.capabilities = nil
        end)
      end
      if code > 0 then
        vim.schedule(function()
          require("copilot.status").status()
        end)
      end
    end,
    handlers = require("copilot.client.handlers").get_handlers(),
    init_options = {
      editorInfo = editor_info.editorInfo,
      editorPluginInfo = editor_info.editorPluginInfo,
    },
    settings = settings,
    workspace_folders = workspace_folders,
  }, overrides)
end

---@param callback fun(client:table)
function M.add_callback(callback)
  table.insert(callbacks, callback)
end

return M
