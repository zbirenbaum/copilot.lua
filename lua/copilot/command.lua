local a = require("copilot.api")
local c = require("copilot.client")
local u = require("copilot.util")

local M = {}

function M.version()
  local info = u.get_editor_info()

  ---@type (string|table)[]
  local lines = {
    info.editorInfo.name .. " " .. info.editorInfo.version,
    "copilot.vim" .. " " .. info.editorPluginInfo.version,
    "copilot.lua" .. " " .. u.get_copilot_lua_version(),
  }

  local client = c.get()

  coroutine.wrap(function()
    -- TODO: this is now in lsp/*
    local copilot_server_info = u.get_copilot_server_info()
    if client then
      local _, data = a.get_version(client)
      lines[#lines + 1] = copilot_server_info.path .. "/" .. copilot_server_info().filename .. " " .. data.version
    else
      lines[#lines + 1] = copilot_server_info.path .. "/" .. copilot_server_info().filename .. " " .. "not running"
    end

    local chunks = {}
    for _, line in ipairs(lines) do
      chunks[#chunks + 1] = type(line) == "table" and line or { line }
      chunks[#chunks + 1] = { "\n", "NONE" }
    end

    vim.api.nvim_echo(chunks, true, {})
  end)()
end

---@param opts? { force?: boolean }
function M.attach(opts)
  opts = opts or {}

  if not opts.force then
    local should_attach, no_attach_reason = u.should_attach()
    -- TODO: add other should_attach method here
    if not should_attach then
      vim.api.nvim_echo({
        { "[Copilot] " .. no_attach_reason .. "\n" },
        { "[Copilot] to force attach, run ':Copilot! attach'" },
      }, true, {})
      return
    end

    opts.force = true
  end

  c.buf_attach(opts.force)
end

function M.detach()
  if c.buf_is_attached(0) then
    c.buf_detach()
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
  c.setup()
  require("copilot.panel").setup()
  require("copilot.suggestion").setup()
end

function M.disable()
  c.teardown()
  require("copilot.panel").teardown()
  require("copilot.suggestion").teardown()
end

return M
