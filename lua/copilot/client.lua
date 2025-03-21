local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")

local is_disabled = false

local M = {
  augroup = "copilot.client",
  id = nil,
  --- @class copilot_capabilities:lsp.ClientCapabilities
  --- @field copilot table<'openURL', boolean>
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
      error("unexpectedly started multiple copilot servers")
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
    print("[Copilot] Offline")
    return
  end

  if not force and not util.should_attach() then
    return
  end

  if not M.config then
    vim.notify("[Copilot] Cannot attach: configuration not initialized", vim.log.levels.ERROR)
    return
  end

  local ok, client_id_or_err = pcall(lsp_start, M.config)
  if not ok then
    vim.notify(string.format("[Copilot] Failed to start LSP client: %s", client_id_or_err), vim.log.levels.ERROR)
    return
  end

  if client_id_or_err then
    store_client_id(client_id_or_err)
  else
    vim.notify("[Copilot] LSP client failed to start (no client ID returned)", vim.log.levels.ERROR)
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
    print("[Copilot] Offline")
    return
  end

  local client = M.get() --[[@as table]]

  if not client then
    if not M.config then
      error("copilot.setup is not called yet")
    end

    local client_id, err = vim.lsp.start_client(M.config)

    if not client_id then
      error(string.format("[Copilot] Error starting LSP Client: %s", err))
      return
    end

    store_client_id(client_id)

    client = M.get() --[[@as table]]
  end

  if client.initialized then
    callback(client)
    return
  end

  local timer, err, _ = vim.loop.new_timer()

  if not timer then
    error(string.format("[Copilot] Error creating timer: %s", err))
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

local function prepare_client_config(overrides)
  local node = config.get("copilot_node_command")

  if vim.fn.executable(node) ~= 1 then
    local err = string.format("copilot_node_command(%s) is not executable", node)
    vim.notify("[Copilot] " .. err, vim.log.levels.ERROR)
    M.startup_error = err
    return
  end

  local agent_path = vim.api.nvim_get_runtime_file("copilot/dist/language-server.js", false)[1]
  if not agent_path or vim.fn.filereadable(agent_path) == 0 then
    local err = string.format("Could not find language-server.js (bad install?) : %s", tostring(agent_path))
    vim.notify("[Copilot] " .. err, vim.log.levels.ERROR)
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

  local handlers = {
    PanelSolution = api.handlers.PanelSolution,
    PanelSolutionsDone = api.handlers.PanelSolutionsDone,
    statusNotification = api.handlers.statusNotification,
    ["copilot/openURL"] = api.handlers["copilot/openURL"],
  }

  local root_dir = vim.loop.cwd()
  if not root_dir then
    root_dir = vim.fn.getcwd()
  end

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
        api.set_editor_info(client, set_editor_info_params, function(err)
          if err then
            vim.notify(string.format("[copilot] setEditorInfo failure: %s", err), vim.log.levels.ERROR)
          end
        end)
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
    handlers = handlers,
    init_options = {
      copilotIntegrationId = "vscode-chat",
    },
    workspace_folders = workspace_folders,
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
    vim.notify("[Copilot] Workspace folder path must be a string", vim.log.levels.ERROR)
    return false
  end

  if vim.fn.isdirectory(folder_path) ~= 1 then
    vim.notify("[Copilot] Invalid workspace folder: " .. folder_path, vim.log.levels.ERROR)
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
    vim.notify("[Copilot] Added workspace folder: " .. folder_path, vim.log.levels.INFO)
  else
    vim.notify("[Copilot] Workspace folder added for next session: " .. folder_path, vim.log.levels.INFO)
  end

  return true
end

return M
