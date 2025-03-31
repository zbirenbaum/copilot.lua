local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local lsp = require("copilot.lsp")
local utils = require("copilot.client.utils")

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
  if lsp.binary.initialization_failed then
    M.startup_error = "initialization of copilot-language-server failed"
    return
  end

  if is_disabled then
    logger.warn("copilot is disabled")
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if not (force or (config.should_attach(bufnr, bufname) and util.should_attach())) then
    logger.debug("not attaching to buffer based on force and should_attach criteria")
    return
  end

  if not M.config then
    logger.error("cannot attach: configuration not initialized")
    return
  end

  -- In case it has changed, we update it
  M.config.root_dir = utils.get_root_dir(config.root_dir)

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

function M.setup()
  local node_command = config.copilot_node_command

  --TODO: merge the two types into an indirection
  if config.server.type == "nodejs" then
    lsp.nodejs.setup(node_command, config.server.custom_server_filepath)
  elseif config.server.type == "binary" then
    lsp.binary.setup(config.server.custom_server_filepath)
  end

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
