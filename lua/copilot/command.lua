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
  local function on_output(err)
    print("[Copilot] " .. err)
  end

  local client = u.get_copilot_client()
  if not client then
    on_output("Not running")
    return
  end

  coroutine.wrap(function()
    ---@todo check startup error

    local cserr, status = a.check_status(client)
    if cserr then
      on_output(cserr)
      return
    end

    ---@todo check enabled status

    if not status.user then
      on_output("Not authenticated. Run ':Copilot auth'")
      return
    end

    if string.lower(a.status.data.status) == "error" then
      on_output(a.status.data.message)
      return
    end

    on_output("Enabled and online")
  end)()
end

---@param opts? { force?: boolean }
function mod.toggle(opts)
  opts = opts or {}
  print(vim.inspect(opts))

  local client = u.get_copilot_client()
  if not client then
    return
  end

  if u.is_attached(client) then
    c.buf_detach(client)
  else
    c.buf_attach(client, opts.force)
  end
end

return mod
