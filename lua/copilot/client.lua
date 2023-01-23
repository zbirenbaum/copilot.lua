local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")

local M = {
  id = nil,
}

local function store_client_id(id)
  if M.id and M.id ~= id then
    if vim.lsp.get_client_by_id(M.id) then
      error("unexpectedly started multiple copilot server")
    end
  end

  M.id = id
end

local copilot_node_version = nil
function M.get_node_version()
  if not copilot_node_version then
    copilot_node_version = string.match(
      table.concat(vim.fn.systemlist(config.get("copilot_node_command") .. " --version", nil, false)),
      "v(%S+)"
    )
  end
  return copilot_node_version
end

function M.buf_is_attached(bufnr)
  return M.id and vim.lsp.buf_is_attached(bufnr or 0, M.id)
end

---@param force? boolean
function M.buf_attach(force)
  if not force and not util.should_attach() then
    return
  end

  local client_id = vim.lsp.start(M.config)
  store_client_id(client_id)
end

function M.buf_detach()
  if M.buf_is_attached(0) then
    vim.lsp.buf_detach_client(0, M.id)
  end
end

---@param should_start? boolean
function M.get(should_start)
  if not M.config then
    error("copilot.setup is not called yet")
  end

  local client = M.id and vim.lsp.get_client_by_id(M.id) or nil

  if should_start and not (M.id and client) then
    local client_id = vim.lsp.start_client(M.config)
    store_client_id(client_id)

    client = vim.lsp.get_client_by_id(M.id)
  end

  return client
end

---@param callback fun(client:table):nil
function M.use_client(callback)
  local client = M.get(true) --[[@as table]]

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
        api.set_editor_info(client, set_editor_info_params)
      end)
    end,
    handlers = {
      PanelSolution = api.handlers.PanelSolution,
      PanelSolutionsDone = api.handlers.PanelSolutionsDone,
      statusNotification = api.handlers.statusNotification,
    },
  }, params.server_opts_overrides or {})
end

M.setup = function(params)
  M.config = M.merge_server_opts(params)

  local augroup = vim.api.nvim_create_augroup("copilot.client", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    callback = vim.schedule_wrap(function()
      M.buf_attach()
    end),
  })

  vim.schedule(function()
    M.buf_attach()
  end)
end

return M
