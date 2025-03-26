local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local lsp_binary_util = require("copilot.lsp_binary")

local is_disabled = false

local M = {
  augroup = "copilot.client",
  id = nil,
  --- @class copilot_capabilities:lsp.ClientCapabilities
  --- @field copilot table<'openURL', boolean>
  --- @field workspace table<'workspaceFolders', boolean>
  capabilities = nil,
  config = nil,
  startup_error = nil,
  initialized = false,
  ---@type copilot_should_attach
  should_attach = nil,
}

---@param id integer
local function store_client_id(id)
  if M.id and M.id ~= id then
    if vim.lsp.get_client_by_id(M.id) then
      vim.lsp.stop_client(M.id)
    end
  end

  M.id = id
end

function M.buf_is_attached(bufnr)
  return M.id and vim.lsp.buf_is_attached(bufnr or 0, M.id)
end

---@param force? boolean
function M.buf_attach(force)
  if is_disabled then
    logger.warn("copilot is disabled")
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if not (force or (M.should_attach(bufnr, bufname) and util.should_attach())) then
    logger.debug("not attaching to buffer based on force and should_attach criteria")
    return
  end

  if not M.config then
    logger.error("cannot attach: configuration not initialized")
    return
  end

  -- In case it has changed, we update it
  M.config.root_dir = config.get_root_dir()

  local ok, client_id_or_err = pcall(vim.lsp.start, M.config)
  if not ok then
    logger.error(string.format("failed to start LSP client: %s", client_id_or_err))
    return
  end

  if client_id_or_err then
    store_client_id(client_id_or_err)
  else
    logger.error("LSP client failed to start (no client ID returned)")
  end
end

function M.buf_detach()
  if M.buf_is_attached(0) then
    vim.lsp.buf_detach_client(0, M.id)
  end
end

---@return nil|vim.lsp.Client
function M.get()
  return vim.lsp.get_client_by_id(M.id)
end

function M.is_disabled()
  return is_disabled
end

---@param callback fun(client:table):nil
function M.use_client(callback)
  if is_disabled then
    logger.warn("copilot is offline")
    return
  end

  local client = M.get() --[[@as table]]

  if not client then
    if not M.config then
      logger.error("copilot.setup is not called yet")
      return
    end

    local client_id, err = vim.lsp.start(M.config)

    if not client_id then
      logger.error(string.format("error starting LSP client: %s", err))
      return
    end

    store_client_id(client_id)

    client = M.get() --[[@as table]]
  end

  if client.initialized then
    callback(client)
    return
  end

  local timer, err, _ = vim.uv.new_timer()

  if not timer then
    logger.error(string.format("error creating timer: %s", err))
    return
  end

  timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if client.initialized and not timer:is_closing() then
        timer:stop()
        timer:close()
        callback(client)
      end
    end)
  )
end

local function get_handlers()
  local handlers = {
    PanelSolution = api.handlers.PanelSolution,
    PanelSolutionsDone = api.handlers.PanelSolutionsDone,
    statusNotification = api.handlers.statusNotification,
    ["window/showDocument"] = util.show_document,
  }

  -- optional handlers
  local logger_conf = config.get("logger") --[[@as copilot_config_logging]]
  if logger_conf.trace_lsp ~= "off" then
    handlers = vim.tbl_extend("force", handlers, {
      ["$/logTrace"] = logger.handle_lsp_trace,
    })
  end

  if logger_conf.trace_lsp_progress then
    handlers = vim.tbl_extend("force", handlers, {
      ["$/progress"] = logger.handle_lsp_progress,
    })
  end

  if logger_conf.log_lsp_messages then
    handlers = vim.tbl_extend("force", handlers, {
      ["window/logMessage"] = logger.handle_log_lsp_messages,
    })
  end

  return handlers
end

local function prepare_client_config(overrides)
  if lsp_binary_util.initialization_failed then
    M.startup_error = "initialization of copilot-language-server failed"
    return
  end

  local server_path = lsp_binary_util.get_copilot_server_info().absolute_filepath

  M.startup_error = nil

  local capabilities = vim.lsp.protocol.make_client_capabilities() --[[@as copilot_capabilities]]
  capabilities.window.showDocument.support = true

  capabilities.workspace = {
    workspaceFolders = true,
  }

  local root_dir = config.get_root_dir()
  local workspace_folders = {
    --- @type workspace_folder
    {
      uri = vim.uri_from_fname(root_dir),
      -- important to keep root_dir as-is for the name as lsp.lua uses this to check the workspace has not changed
      name = root_dir,
    },
  }

  local config_workspace_folders = config.get("workspace_folders") --[[@as table<string>]]

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
  local provider_url = config.get("auth_provider_url") --[[@as string|nil]]
  local proxy_uri = vim.g.copilot_proxy

  local settings = { ---@type copilot_settings
    telemetry = { ---@type github_settings_telemetry
      telemetryLevel = "all",
    },
  }

  if proxy_uri then
    vim.tbl_extend("force", settings, {
      http = { ---@type copilot_settings_http
        proxy = proxy_uri,
        proxyStrictSSL = vim.g.copilot_proxy_strict_ssl or false,
        proxyKerberosServicePrincipal = nil,
      },
    })
  end

  if provider_url then
    vim.tbl_extend("force", settings, {
      ["github-enterprise"] = { ---@type copilot_settings_github-enterprise
        uri = provider_url,
      },
    })
  end

  -- LSP config, not to be confused with config.lua
  return vim.tbl_deep_extend("force", {
    cmd = {
      server_path,
      "--stdio",
    },
    root_dir = root_dir,
    name = "copilot",
    capabilities = capabilities,
    get_language_id = function(_, filetype)
      return util.language_for_file_type(filetype)
    end,
    on_init = function(client, initialize_result)
      if M.id == client.id then
        M.capabilities = initialize_result.capabilities
      end

      vim.schedule(function()
        local configurations = util.get_workspace_configurations()
        api.notify_change_configuration(client, configurations)
        logger.trace("workspace configuration", configurations)

        -- to activate tracing if we want it
        local logger_conf = config.get("logger") --[[@as copilot_config_logging]]
        local trace_params = { value = logger_conf.trace_lsp } --[[@as copilot_nofify_set_trace_params]]
        api.notify_set_trace(client, trace_params)

        -- prevent requests to copilot prior to being initialized
        M.initialized = true
      end)
    end,
    on_exit = function(code, _, client_id)
      if M.id == client_id then
        vim.schedule(function()
          M.teardown()
          M.id = nil
          M.capabilities = nil
        end)
      end
      if code > 0 then
        vim.schedule(function()
          require("copilot.command").status()
        end)
      end
    end,
    handlers = get_handlers(),
    init_options = {
      copilotIntegrationId = "vscode-chat", -- can be safely removed with copilot v1.291
      editorInfo = editor_info.editorInfo,
      editorPluginInfo = editor_info.editorPluginInfo,
    },
    settings = settings,
    workspace_folders = workspace_folders,
    trace = config.get("trace") or "off",
  }, overrides)
end

function M.setup()
  M.config = prepare_client_config(config.get("server_opts_overrides"))
  M.should_attach = config.get("should_attach") --[[@as copilot_should_attach]]

  if not M.config then
    is_disabled = true
    return
  end

  is_disabled = false

  M.id = nil
  vim.api.nvim_create_augroup(M.augroup, { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup,
    callback = vim.schedule_wrap(function()
      M.buf_attach()
    end),
  })

  vim.schedule(function()
    if lsp_binary_util.ensure_client_is_downloaded() then
      M.buf_attach()
    end
  end)
end

function M.teardown()
  is_disabled = true

  vim.api.nvim_clear_autocmds({ group = M.augroup })

  if M.id then
    vim.lsp.stop_client(M.id)
  end
end

function M.add_workspace_folder(folder_path)
  if type(folder_path) ~= "string" then
    logger.error("workspace folder path must be a string")
    return false
  end

  if vim.fn.isdirectory(folder_path) ~= 1 then
    logger.error("invalid workspace folder: " .. folder_path)
    return false
  end

  -- Normalize path
  folder_path = vim.fn.fnamemodify(folder_path, ":p")

  --- @type workspace_folder
  local workspace_folder = {
    uri = vim.uri_from_fname(folder_path),
    name = folder_path,
  }

  local workspace_folders = config.get("workspace_folders") --[[@as table<string>]]
  if not workspace_folders then
    workspace_folders = {}
  end

  for _, existing_folder in ipairs(workspace_folders) do
    if existing_folder == folder_path then
      return
    end
  end

  table.insert(workspace_folders, { folder_path })
  config.set("workspace_folders", workspace_folders)

  local client = M.get()
  if client and client.initialized then
    api.notify(client, "workspace/didChangeWorkspaceFolders", {
      event = {
        added = { workspace_folder },
        removed = {},
      },
    })
    logger.notify("added workspace folder: " .. folder_path)
  else
    logger.notify("workspace folder will be added on next session: " .. folder_path)
  end

  return true
end

return M
