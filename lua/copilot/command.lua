local a = require("copilot.api")
local c = require("copilot.client")
local u = require("copilot.util")

local mod = {}

function mod.version()
  local info = u.get_editor_info()

  ---@type (string|table)[]
  local lines = {
    info.editorInfo.name .. " " .. info.editorInfo.version,
    "copilot.vim" .. " " .. info.editorPluginInfo.version,
    "copilot.lua" .. " " .. u.get_copilot_lua_version(),
  }

  local client = c.get()

  coroutine.wrap(function()
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

function mod.status()
  local lines = {}

  local function add_line(line)
    if not line then
      return
    end

    lines[#lines + 1] = type(line) == "table" and { "[Copilot] " .. line[1], line[2] } or { "[Copilot] " .. line }
    lines[#lines + 1] = { "\n", "NONE" }
  end

  local function flush_lines(last_line)
    add_line(last_line)

    if c.startup_error then
      add_line({ c.startup_error, "WarningMsg" })
    end

    vim.api.nvim_echo(lines, true, {})
  end

  if c.is_disabled() then
    flush_lines("Offline")
    return
  end

  local client = c.get()
  if not client then
    flush_lines("Not Started")
    return
  end

  add_line("Online")

  coroutine.wrap(function()
    local cserr, status = a.check_status(client)
    if cserr then
      flush_lines(cserr)
      return
    end

    if not status.user then
      flush_lines("Not authenticated. Run ':Copilot auth'")
      return
    elseif status.status == "NoTelemetryConsent" then
      flush_lines("Telemetry terms not accepted")
      return
    elseif status.status == "NotAuthorized" then
      flush_lines("Not authorized")
      return
    end

    local should_attach, no_attach_reason = u.should_attach()
    local is_attached = c.buf_is_attached()
    if is_attached then
      if not should_attach then
        add_line("Enabled manually (" .. no_attach_reason .. ")")
      else
        add_line("Enabled for " .. vim.bo.filetype)
      end
    elseif not is_attached then
      if should_attach then
        add_line("Disabled manually for " .. vim.bo.filetype)
      else
        add_line("Disabled (" .. no_attach_reason .. ")")
      end
    end

    if string.lower(a.status.data.status) == "error" then
      add_line(a.status.data.message)
    end

    flush_lines()
  end)()
end

---@param opts? { force?: boolean }
function mod.attach(opts)
  opts = opts or {}

  if not opts.force then
    local should_attach, no_attach_reason = u.should_attach()
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

function mod.detach()
  if c.buf_is_attached(0) then
    c.buf_detach()
  end
end

---@param opts? { force?: boolean }
function mod.toggle(opts)
  opts = opts or {}

  if c.buf_is_attached(0) then
    mod.detach()
    return
  end

  mod.attach(opts)
end

function mod.enable()
  c.setup()
  require("copilot.panel").setup()
  require("copilot.suggestion").setup()
end

function mod.disable()
  c.teardown()
  require("copilot.panel").teardown()
  require("copilot.suggestion").teardown()
end

return mod
