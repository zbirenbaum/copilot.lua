local c = require("copilot.client")
local u = require("copilot.util")
local logger = require("copilot.logger")
local lsp = require("copilot.lsp")

local M = {}

function M.version()
  local info = u.get_editor_info()

  ---@type string
  local lines = info.editorInfo.name
    .. " "
    .. info.editorInfo.version
    .. "\n"
    .. "copilot language server"
    .. " "
    .. info.editorPluginInfo.version
    .. "\n"
    .. "copilot.lua"
    .. " "
    .. u.get_copilot_lua_version()

  local client = c.get()

  coroutine.wrap(function()
    local server_info = lsp.get_server_info(client)
    logger.notify(lines .. "\n" .. server_info)
  end)()
end

---@param opts? { force?: boolean, bufnr?: integer}
function M.attach(opts)
  logger.trace("attaching to buffer")
  opts = opts or {}

  if not opts.force then
    local should_attach, no_attach_reason = u.should_attach(opts.bufnr)

    if not should_attach then
      logger.notify(no_attach_reason .. "\nto force attach, run ':Copilot! attach'")
      return
    end

    opts.force = true
  end

  c.buf_attach(opts.force, opts.bufnr)
end

function M.detach()
  local bufnr = vim.api.nvim_get_current_buf()
  if c.buf_is_attached(bufnr) then
    c.buf_detach_if_attached(bufnr)
    logger.trace("buffer manually detached")
    u.set_buffer_attach_status(bufnr, ATTACH_STATUS_MANUALLY_DETACHED)
  end
end

---@param opts? { force?: boolean }
function M.toggle(opts)
  opts = opts or {}

  if c.buf_is_attached(0) then
    M.detach()
    return
  end

  M.attach(opts)
end

function M.enable()
  logger.trace("enabling Copilot")
  c.setup()
  require("copilot.panel").setup()
  require("copilot.suggestion").setup()
end

function M.disable()
  logger.trace("disabling Copilot")
  c.teardown()
  require("copilot.panel").teardown()
  require("copilot.suggestion").teardown()
end

return M
