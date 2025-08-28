local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local lsp = require("copilot.lsp")
local utils = require("copilot.client.utils")
local client_config = require("copilot.client.config")

local is_disabled = false

---@class CopilotClient
---@field augroup string|nil
---@field id integer|nil
---@field capabilities lsp.ClientCapabilities | nil
---@field config vim.lsp.ClientConfig | nil
---@field startup_error string | nil
---@field initialized boolean
local M = {
  augroup = nil,
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
---@param bufnr? integer The buffer number of which will be attached. 0 or nil for current buffer
function M.buf_attach(force, bufnr)
  if bufnr then
    logger.trace("request to attach buffer #" .. tostring(bufnr))
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    logger.trace("buffer is invalid")
    return
  end

  if M.buf_is_attached(bufnr) then
    logger.trace("buffer already attached")
    return
  end

  if (not force) and util.get_buffer_attach_status(bufnr) == ATTACH_STATUS_MANUALLY_DETACHED then
    logger.trace("buffer not attaching as it was manually detached")
    return
  end

  if lsp.initialization_failed() then
    logger.error("copilot-language-server failed to initialize")
    M.startup_error = "initialization of copilot-language-server failed"
    return
  end

  if is_disabled then
    logger.warn("copilot is disabled")
    return
  end

  local should_attach, reason = util.should_attach(bufnr)

  if not (force or should_attach) then
    logger.debug("not attaching to buffer based should_attach criteria: " .. reason)
    util.set_buffer_attach_status(bufnr, ATTACH_STATUS_NOT_ATTACHED_PREFIX .. reason)
    return
  end

  if not M.config then
    logger.error("cannot attach: configuration not initialized")
    return
  end

  logger.trace("attaching to buffer")

  if not M.id then
    M.ensure_client_started()
  end

  if not M.id then
    logger.error("failed to start copilot client")
    return
  end

  vim.lsp.buf_attach_client(bufnr, M.id)
  util.set_buffer_previous_ft(bufnr, vim.bo[bufnr].filetype)
  if force then
    logger.debug("force attached to buffer")
    util.set_buffer_attach_status(bufnr, ATTACH_STATUS_FORCE_ATTACHED)
  else
    logger.trace("buffer attached")
    util.set_buffer_attach_status(bufnr, ATTACH_STATUS_ATTACHED)
  end
end

---@param bufnr? integer
function M.buf_detach_if_attached(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.buf_is_attached(bufnr) then
    vim.lsp.buf_detach_client(bufnr, M.id)
    util.set_buffer_attach_status(bufnr, ATTACH_STATUS_NOT_ATTACHED_PREFIX .. "detached")
  end
end

---@return vim.lsp.Client|nil
function M.get()
  return vim.lsp.get_client_by_id(M.id)
end

---@return boolean
function M.is_disabled()
  return is_disabled
end

function M.ensure_client_started()
  if M.id then
    return
  end

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

  M.config.root_dir = utils.get_root_dir(config.root_dir)
  local client_id, err = vim.lsp.start(M.config, { attach = false })

  if not client_id then
    logger.error(string.format("error starting LSP client: %s", err))
    return
  end

  store_client_id(client_id)
end

---@param callback fun(client:table):nil
function M.use_client(callback)
  local client = M.get()
  if client then
    callback(client)
  end
end

---@param bufnr integer
local function on_filetype(bufnr)
  logger.trace("filetype autocmd called")
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    -- todo: when we do lazy/late attaching this needs changing

    -- This is to handle the case where the filetype changes after the buffer is already attached,
    -- causing the LSP to raise an error
    if util.get_buffer_previous_ft(bufnr) ~= vim.bo[bufnr].filetype then
      logger.trace("filetype changed, detaching and re-attaching")
      M.buf_detach_if_attached(bufnr)
    end

    M.buf_attach(false, bufnr)
  end)
end

function M.setup()
  logger.trace("setting up client")
  local node_command = config.copilot_node_command
  if not lsp.setup(config.server, node_command) then
    is_disabled = true
    return
  end

  M.config = require("copilot.client.config").prepare_client_config(config.server_opts_overrides, M)

  if not M.config then
    is_disabled = true
    return
  end

  is_disabled = false
  M.id = nil

  -- nvim_clear_autocmds throws an error if the group does not exist
  local augroup = "copilot.client"
  vim.api.nvim_create_augroup(augroup, { clear = true })
  M.augroup = augroup

  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup,
    callback = function(args)
      local bufnr = (args and args.buf) or nil
      on_filetype(bufnr)
    end,
    desc = "[copilot] (suggestion) file type",
  })

  vim.schedule(M.ensure_client_started)
  -- FileType is likely already triggered for shown buffer, so we trigger it manually
  local bufnr = vim.api.nvim_get_current_buf()
  vim.schedule(function()
    M.buf_attach(false, bufnr)
  end)
end

function M.teardown()
  is_disabled = true

  -- nvim_clear_autocmds throws an error if the group does not exist
  if M.augroup then
    vim.api.nvim_clear_autocmds({ group = M.augroup })
  end

  if M.id then
    vim.lsp.stop_client(M.id)
  end
end

return M
