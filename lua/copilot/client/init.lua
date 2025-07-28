local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local lsp = require("copilot.lsp")
local utils = require("copilot.client.utils")
local client_config = require("copilot.client.config")

local is_disabled = false

---@class CopilotClient
---@field id integer|nil
---@field capabilities lsp.ClientCapabilities | nil
---@field config vim.lsp.ClientConfig | nil
---@field startup_error string | nil
---@field initialized boolean
local M = {
  augroup = "copilot.client",
  id = nil,
  capabilities = nil,
  config = nil,
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

function M.buf_is_attached(bufnr)
  return M.id and vim.lsp.buf_is_attached(bufnr or 0, M.id)
end

---@param force? boolean
function M.buf_attach(force)
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if lsp.initialization_failed() then
    logger.error("copilot-language-server failed to initialize")
    M.startup_error = "initialization of copilot-language-server failed"
    return
  end

  if is_disabled then
    logger.warn("copilot is disabled")
    return
  end

  if not (force or util.should_attach()) then
    logger.debug("not attaching to buffer based on force and should_attach criteria")
    return
  end

  if not M.config then
    logger.debug("initializing config for attachable buffer")
    M.config = client_config.create(config)
  end
  if not M.config then
    logger.error("cannot attach: configuration not initialized")
    return
  end

  -- In case it has changed, we update it
  M.config.root_dir = utils.get_root_dir(config.root_dir)

  logger.trace("attaching to buffer")
  -- Only attach client to buffer, do not start client here
  local client = M.get()
  if client and not vim.lsp.buf_is_attached(bufnr, client.id) then
    vim.lsp.buf_attach_client(bufnr, client.id)
    logger.trace("explicitly attached client to buffer", bufnr, client.id)
  end
  logger.debug(
    string.format(
      "[buf_attach] After attach: bufnr=%s, filetype=%s, attached=%s",
      tostring(bufnr),
      tostring(filetype),
      tostring(client and vim.lsp.buf_is_attached(bufnr, client.id) or false)
    )
  )
  logger.trace("buffer attached")
end

function M.buf_detach()
  if M.buf_is_attached(0) then
    vim.lsp.buf_detach_client(0, M.id)
  end
end

---@return vim.lsp.Client|nil
function M.get()
  return vim.lsp.get_client_by_id(M.id)
end

function M.is_disabled()
  return is_disabled
end

function M.ensure_client_started()
  if is_disabled then
    logger.notify("copilot is offline")
    return
  end

  if not M.config then
    M.config = client_config.create(config)
  end

  if not M.config then
    logger.error("copilot.setup is not called yet")
    return
  end

  if not M.id then
    local client_id, err = vim.lsp.start(M.config)
    if not client_id then
      logger.error(string.format("error starting LSP client: %s", err))
      return
    end
    store_client_id(client_id)
  end
end

---@param callback fun(client:table):nil
function M.use_client(callback)
  M.ensure_client_started()
  local client = M.get()
  if client then
    callback(client)
  end
end

function M.setup()
  logger.trace("setting up client")
  local node_command = config.copilot_node_command
  lsp.setup(config.server, node_command)
  M.config = require("copilot.client.config").prepare_client_config(config.server_opts_overrides, M)

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

return M
