local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")

local is_disabled = false

local M = {
  augroup = "copilot.client",
  id = nil,
  --- @class copilot_capabilities:lsp.ClientCapabilities
  --- @field copilot table<'openURL', boolean>
  --- @field workspace table<'workspaceFolders', boolean>
  capabilities = nil,
  config = nil,
  node_version = nil,
  node_version_error = nil,
  startup_error = nil,
  initialized = false,
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

local lsp_start = vim.lsp.start
if not lsp_start then
  local function reuse_client(client, conf)
    return client.config.root_dir == conf.root_dir and client.name == conf.name
  end

  -- shim for neovim < 0.8.2
  lsp_start = function(lsp_config)
    local bufnr = vim.api.nvim_get_current_buf()
    local client = M.get()
    if client and reuse_client(client, lsp_config) then
      vim.lsp.buf_attach_client(bufnr, client.id)
      return client.id
    end
    local client_id = vim.lsp.start_client(lsp_config) --[[@as number]]
    vim.lsp.buf_attach_client(bufnr, client_id)
    return client_id
  end
end

---@return string node_version
---@return nil|string node_version_error
function M.get_node_version()
  if not M.node_version then
    local node = config.get("copilot_node_command")

    local cmd = { node, "--version" }
    local cmd_output_table = vim.fn.executable(node) == 1 and vim.fn.systemlist(cmd, nil, 0) or { "" }
    local cmd_output = cmd_output_table[#cmd_output_table]
    local cmd_exit_code = vim.v.shell_error

    local node_version = string.match(cmd_output, "^v(%S+)") or ""
    local node_version_major = tonumber(string.match(node_version, "^(%d+)%.")) or 0
    local node_version_minor = tonumber(string.match(node_version, "^%d+%.(%d+)%.")) or 0

    if node_version_major == 0 then
      M.node_version_error = table.concat({
        "Could not determine Node.js version",
        "-----------",
        "(exit code) " .. tostring(cmd_exit_code),
        "   (output) " .. cmd_output,
        "-----------",
      }, "\n")
    elseif
      node_version_major < 16
      or (node_version_major == 16 and node_version_minor < 14)
      or (node_version_major == 17 and node_version_minor < 3)
    then
      M.node_version_error = string.format("Node.js version 18.x or newer required but found %s", node_version)
    end

    M.node_version = node_version or ""
  end

  return M.node_version, M.node_version_error
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

  if not force and not util.should_attach() then
    return
  end

  if not M.config then
    logger.error("cannot attach: configuration not initialized")
    return
  end

  -- In case it has changed, we update it
  M.config.root_dir = config.get_root_dir()

  local ok, client_id_or_err = pcall(lsp_start, M.config)
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

    local client_id, err = vim.lsp.start_client(M.config)

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
    ["copilot/openURL"] = api.handlers["copilot/openURL"],
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
  local node = config.get("copilot_node_command")

  if vim.fn.executable(node) ~= 1 then
    local err = string.format("copilot_node_command(%s) is not executable", node)
    logger.error(err)
    M.startup_error = err
    return
  end

  local agent_path = vim.api.nvim_get_runtime_file("copilot/dist/language-server.js", false)[1]
  if not agent_path or vim.fn.filereadable(agent_path) == 0 then
    local err = string.format("Could not find language-server.js (bad install?) : %s", tostring(agent_path))
    logger.error(err)
    M.startup_error = err
    return
  end

  M.startup_error = nil

  local capabilities = vim.lsp.protocol.make_client_capabilities() --[[@as copilot_capabilities]]
  capabilities.copilot = {
    openURL = true,
  }
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

  -- LSP config, not to be confused with config.lua
  return vim.tbl_deep_extend("force", {
    cmd = {
      node,
      agent_path,
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
        local set_editor_info_params = util.get_editor_info() --[[@as copilot_set_editor_info_params]]
        set_editor_info_params.editorConfiguration = util.get_editor_configuration()
        set_editor_info_params.networkProxy = util.get_network_proxy()
        local provider_url = config.get("auth_provider_url")
        set_editor_info_params.authProvider = provider_url and {
          url = provider_url,
        } or nil

        logger.debug("data for setEditorInfo LSP call", set_editor_info_params)
        api.set_editor_info(client, set_editor_info_params, function(err)
          if err then
            logger.error(string.format("setEditorInfo failure: %s", err))
          end
        end)
        logger.trace("setEditorInfo has been called")
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
      copilotIntegrationId = "vscode-chat",
      -- Fix LSP warning: editorInfo and editorPluginInfo will soon be required in initializationOptions
      -- We are sending these twice for the time being as it will become required here and we get a warning if not set.
      -- However if not passed in setEditorInfo, that one returns an error.
      editorInfo = editor_info.editorInfo,
      editorPluginInfo = editor_info.editorPluginInfo,
    },
    workspace_folders = workspace_folders,
    trace = config.get("trace") or "off",
  }, overrides)
end

function M.setup()
  M.config = prepare_client_config(config.get("server_opts_overrides"))

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
    M.buf_attach()
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
    client.notify("workspace/didChangeWorkspaceFolders", {
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
