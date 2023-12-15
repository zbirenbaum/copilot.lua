local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")

local is_disabled = false

local M = {
  augroup = "copilot.client",
  id = nil,
  capabilities = nil,
  config = nil,
  node_version = nil,
  node_version_error = nil,
  startup_error = nil,
}

---@param id number
local function store_client_id(id)
  if M.id and M.id ~= id then
    if vim.lsp.get_client_by_id(M.id) then
      error("unexpectedly started multiple copilot server")
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
    local cmd_output_table = vim.fn.executable(node) == 1 and vim.fn.systemlist(cmd, nil, false) or { "" }
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

  local client_id = lsp_start(M.config)
  store_client_id(client_id)
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

    local client_id = vim.lsp.start_client(M.config)
    store_client_id(client_id)

    client = M.get()
  end

  if client.initialized then
    callback(client)
    return
  end

  local timer = vim.loop.new_timer()
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

  local agent_path = vim.api.nvim_get_runtime_file("copilot/index.js", false)[1]
  if vim.fn.filereadable(agent_path) == 0 then
    local err = string.format("Could not find agent.js (bad install?) : %s", agent_path)
    vim.notify("[Copilot] " .. err, vim.log.levels.ERROR)
    M.startup_error = err
    return
  end

  M.startup_error = nil

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.copilot = {
    openURL = true,
  }

  local handlers = {
    PanelSolution = api.handlers.PanelSolution,
    PanelSolutionsDone = api.handlers.PanelSolutionsDone,
    statusNotification = api.handlers.statusNotification,
    ["copilot/openURL"] = api.handlers["copilot/openURL"],
  }

  return vim.tbl_deep_extend("force", {
    cmd = {
      node,
      agent_path,
    },
    root_dir = vim.loop.cwd(),
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
        ---@type copilot_set_editor_info_params
        local set_editor_info_params = util.get_editor_info()
        set_editor_info_params.editorConfiguration = util.get_editor_configuration()
        set_editor_info_params.networkProxy = util.get_network_proxy()
        api.set_editor_info(client, set_editor_info_params, function(err)
          if err then
            vim.notify(string.format("[copilot] setEditorInfo failure: %s", err), vim.log.levels.ERROR)
          end
        end)
      end)
    end,
    on_exit = function(code, _signal, client_id)
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
  }, overrides)
end

function M.setup()
  M.config = prepare_client_config(config.get("server_opts_overrides"))

  if not M.config then
    is_disabled = true
    return
  end

  is_disabled = false

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

return M
