local a = require("copilot.api")
local c = require("copilot.client")
local u = require("copilot.util")

local mod = {}

function mod.version()
  local info = u.get_editor_info()

  local lines = {
    info.editorInfo.name .. " " .. info.editorInfo.version,
    info.editorPluginInfo.name .. " " .. info.editorPluginInfo.version,
    "copilot.lua" .. " " .. u.get_copilot_lua_version(),
  }

  local client = u.get_copilot_client()

  coroutine.wrap(function()
    if client then
      local _, data = a.get_version(client)
      lines[#lines + 1] = "copilot/dist/agent.js" .. " " .. data.version
      lines[#lines + 1] = "Node.js" .. " " .. c.get_node_version()
    else
      lines[#lines + 1] = "copilot/dist/agent.js" .. " " .. "not running"
    end

    vim.api.nvim_echo(
      vim.tbl_map(function(line)
        return { line .. "\n" }
      end, lines),
      true,
      {}
    )
  end)()
end

function mod.status()
  local lines = {}

  local function add_line(line)
    lines[#lines + 1] = { "[Copilot] " .. line .. "\n" }
  end

  local function flush_lines(last_line)
    if last_line then
      add_line(last_line)
    end

    vim.api.nvim_echo(lines, true, {})
  end

  local client = u.get_copilot_client()
  if not client then
    flush_lines("Not running")
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
    elseif status.status == 'NoTelemetryConsent' then
      flush_lines("Telemetry terms not accepted")
      return
    elseif status.status == 'NotAuthorized' then
      flush_lines("Not authorized")
      return
    end

    local should_attach, no_attach_reason = u.should_attach(c.params.filetypes)
    local is_attached = u.is_attached(client)
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
function mod.toggle(opts)
  opts = opts or {}

  local client = u.get_copilot_client()
  if not client then
    return
  end

  if u.is_attached(client) then
    c.buf_detach(client)
    return
  end

  if not opts.force then
    local should_attach, no_attach_reason = u.should_attach(c.params.filetypes)
    if not should_attach then
      vim.api.nvim_echo({
        { "[Copilot] " .. no_attach_reason .. "\n" },
        { "[Copilot] to force enable, run ':Copilot! toggle'" },
      }, true, {})
      return
    end

    opts.force = true
  end

  c.buf_attach(client, opts.force)
end

return mod
