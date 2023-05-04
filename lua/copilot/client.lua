local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")

local is_disabled = false

local M = {
  id = nil,
  augroup = "copilot.client",
}

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

local copilot_node_version = nil
function M.get_node_version()
  if not copilot_node_version then
    local node_version = string.match(
      table.concat(vim.fn.systemlist(config.get("copilot_node_command") .. " --version", nil, false)) or "",
      "v(%S+)"
    )

    if not node_version then
      error("[Copilot] Node.js not found")
    end

    local node_version_major = tonumber(string.match(node_version, "^(%d+)%."))
    if node_version_major < 16 then
      vim.notify(
        string.format("[Copilot] Node.js version 16.x or newer required but found %s", copilot_node_version),
        vim.log.levels.ERROR
      )
    end

    copilot_node_version = node_version
  end
  return copilot_node_version
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

M.merge_server_opts = function(params)
  return vim.tbl_deep_extend("force", {
    cmd = {
      params.copilot_node_command,
      require("copilot.util").get_copilot_path(),
    },
    root_dir = vim.loop.cwd(),
    name = "copilot",
    on_init = function(client)
      vim.schedule(function()
        ---@type copilot_set_editor_info_params
        local set_editor_info_params = util.get_editor_info()
        set_editor_info_params.editorInfo.version = set_editor_info_params.editorInfo.version
          .. " + Node.js "
          .. M.get_node_version()
        set_editor_info_params.editorConfiguration = util.get_editor_configuration()
        set_editor_info_params.networkProxy = util.get_network_proxy()
        api.set_editor_info(client, set_editor_info_params, function(err)
          if err then
            vim.notify(string.format("[copilot] setEditorInfo failure: %s", err), vim.log.levels.ERROR)
          end
        end)
      end)
    end,
    handlers = {
      PanelSolution = api.handlers.PanelSolution,
      PanelSolutionsDone = api.handlers.PanelSolutionsDone,
      statusNotification = api.handlers.statusNotification,
    },
  }, params.server_opts_overrides or {})
end

function M.setup()
  is_disabled = false

  M.config = M.merge_server_opts(config.get())

  if vim.fn.executable(M.config.cmd[1]) ~= 1 then
    is_disabled = true
    vim.notify(
      string.format("[copilot] copilot_node_command(%s) is not executable", M.config.cmd[1]),
      vim.log.levels.ERROR
    )
    return
  end

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
    M.id = nil
  end
end

return M
