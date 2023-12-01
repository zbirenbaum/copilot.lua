local a = require("copilot.api")
local c = require("copilot.client")
local config = require("copilot.config")
local u = require("copilot.util")

local mod = {}

local function node_version_warning(node_version)
  if string.match(node_version, "^16%.") then
    local line = "Warning: Node.js 16 is approaching end of life and support will be dropped in a future release."
    if config.get("copilot_node_command") ~= "node" then
      line = line
        .. " 'copilot_node_command' is set to a non-default value. Consider removing it from your configuration."
    end
    return { line, "MoreMsg" }
  end
end

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
    if client then
      local _, data = a.get_version(client)
      lines[#lines + 1] = "copilot/dist/agent.js" .. " " .. data.version
    else
      lines[#lines + 1] = "copilot/dist/agent.js" .. " " .. "not running"
    end

    local node_version, node_version_error = c.get_node_version()
    lines[#lines + 1] = "Node.js" .. " " .. (#node_version == 0 and "(unknown)" or node_version)
    if node_version_error then
      lines[#lines + 1] = { node_version_error, "WarningMsg" }
    end
    lines[#lines + 1] = node_version_warning(node_version)

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

  local function flush_lines(last_line, is_off)
    add_line(last_line)

    if c.startup_error then
      add_line({ c.startup_error, "WarningMsg" })
    end

    local node_version, node_version_error = c.get_node_version()
    if node_version_error then
      add_line({ node_version_error, "WarningMsg" })
    end

    if not is_off then
      add_line(node_version_warning(node_version))
    end

    vim.api.nvim_echo(lines, true, {})
  end

  if c.is_disabled() then
    flush_lines("Offline", true)
    return
  end

  local client = c.get()
  if not client then
    flush_lines("Not Started", true)
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
