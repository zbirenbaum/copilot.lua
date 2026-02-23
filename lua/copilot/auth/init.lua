local api = require("copilot.api")
local c = require("copilot.client")
local logger = require("copilot.logger")

local M = {}

local function echo(message)
  vim.cmd('echom "[Copilot] ' .. tostring(message):gsub('"', '\\"') .. '"')
end

---@class copilot_auth_cache
---@field authenticated boolean|nil
---@field timestamp number

---@type copilot_auth_cache
local auth_cache = {
  authenticated = nil,
  timestamp = 0,
}

local gate_passed = false

function M.pass_gate()
  gate_passed = true
  require("copilot.suggestion").setup()
  require("copilot.panel").setup()

  -- Set suggestion keymaps on buffers that were attached before auth passed
  local client = c.get()
  if client then
    local suggestion = require("copilot.suggestion")
    for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
      suggestion.set_keymap(bufnr)
    end
  end
end

---@return boolean
function M.is_gate_passed()
  return gate_passed
end

function M.reset_gate()
  gate_passed = false
  require("copilot.suggestion").teardown()
  require("copilot.panel").teardown()
end

---@param lsp_client vim.lsp.Client
function M.check_and_gate(lsp_client)
  local check = coroutine.wrap(function()
    local err, status = api.check_status(lsp_client)
    if not err and status and status.user then
      auth_cache.authenticated = true
      auth_cache.timestamp = vim.loop.now()
      M.pass_gate()
    elseif err then
      logger.error("auth gate check failed: " .. tostring(err))
    else
      logger.debug("auth gate: user not authenticated")
    end
  end)
  check()
end

function M.setup(client)
  local function copy_to_clipboard(str)
    vim.cmd(string.format(
      [[
        let @+ = "%s"
        let @* = "%s"
      ]],
      str,
      str
    ))
  end

  local function open_signin_popup(code, url)
    local lines = {
      " [Copilot] ",
      "",
      " First copy your one-time code: ",
      "   " .. code .. " ",
      " In your browser, visit: ",
      "   " .. url .. " ",
      "",
      " ...waiting, it might take a while and ",
      " this popup will auto close once done... ",
    }
    local height, width = #lines, math.max(unpack(vim.tbl_map(function(line)
      return #line
    end, lines)))

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local winid = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      style = "minimal",
      border = "single",
      row = (vim.o.lines - height) / 2,
      col = (vim.o.columns - width) / 2,
      height = height,
      width = width,
    })
    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal", { win = winid })

    return function()
      vim.api.nvim_win_close(winid, true)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  local initiate_setup = coroutine.wrap(function()
    local cserr, status = api.check_status(client)
    if cserr then
      echo(cserr)
      return
    end

    if status.user then
      echo("Authenticated as GitHub user: " .. status.user)
      auth_cache.authenticated = true
      auth_cache.timestamp = vim.loop.now()
      M.pass_gate()
      return
    end

    local siierr, signin = api.sign_in_initiate(client)
    if siierr then
      echo(siierr)
      return
    end

    if not signin.verificationUri or not signin.userCode then
      echo("Failed to setup")
      return
    end

    copy_to_clipboard(signin.userCode)

    local close_signin_popup = open_signin_popup(signin.userCode, signin.verificationUri)

    local sicerr, confirm = api.sign_in_confirm(client, { userCode = signin.userCode })

    close_signin_popup()

    if sicerr then
      echo(sicerr)
      return
    end

    if string.lower(confirm.status) ~= "ok" then
      echo("Authentication failure: " .. confirm.error.message)
      return
    end

    echo("Authenticated as GitHub user: " .. confirm.user)
    auth_cache.authenticated = true
    auth_cache.timestamp = vim.loop.now()
    M.pass_gate()
  end)

  initiate_setup()
end

function M.signin()
  M.reset_gate()
  auth_cache.authenticated = nil
  auth_cache.timestamp = 0
  c.use_client(function(client)
    M.setup(client)
  end)
end

function M.signout()
  c.use_client(function(client)
    api.check_status(
      client,
      { options = { localChecksOnly = true } },
      ---@param status copilot_check_status_data
      function(err, status)
        if err then
          echo(err)
          return
        end

        if status.user then
          echo("Signed out as GitHub user " .. status.user)
        else
          echo("Not signed in")
        end

        api.sign_out(client, function()
          auth_cache.authenticated = nil
          auth_cache.timestamp = 0
          M.reset_gate()
        end)
      end
    )
  end)
end

---@return string|nil
function M.find_config_path()
  local config = vim.fn.expand("$XDG_CONFIG_HOME")
  if config and vim.fn.isdirectory(config) > 0 then
    return config
  elseif vim.fn.has("win32") > 0 then
    config = vim.fn.expand("~/AppData/Local")
    if vim.fn.isdirectory(config) > 0 then
      return config
    end
  else
    config = vim.fn.expand("~/.config")
    if vim.fn.isdirectory(config) > 0 then
      return config
    end
  end

  logger.error("could not find config path")
end

---@return table|nil
function M.get_creds()
  local filename = M.find_config_path() .. "/github-copilot/apps.json"

  if vim.fn.filereadable(filename) == 0 then
    logger.error("Copilot auth file could not be read from:" .. filename)
    return
  end

  local filedata = vim.api.nvim_eval("readfile('" .. filename .. "')")

  if not filedata or #filedata == 0 then
    logger.error("Copilot's apps.json file not found or empty, make sure to sign in first")
    return
  end

  local appsdata = vim.json.decode(filedata[1])
  return appsdata
end

function M.info()
  local info = M.get_creds()
  if not info then
    logger.error("no GitHub Copilot token found, make sure to sign in first")
    return
  end

  logger.notify("GitHub Copilot token information: ", info)
end

---@param authenticated boolean
---@return number
local function get_cache_ttl(authenticated)
  if authenticated then
    return 300000 -- 5 minutes for true status
  else
    return 30000 -- 30 seconds for false status
  end
end

---@param client vim.lsp.Client
---@param callback? fun(err: any|nil)
local function check_status(client, callback)
  api.check_status(client, {}, function(err, status)
    auth_cache.timestamp = vim.loop.now()

    if not err and status and status.user then
      auth_cache.authenticated = true
    elseif not err then
      auth_cache.authenticated = false
    end

    if callback then
      callback(err)
    end
  end)
end

---@param callback? fun(err: any|nil)
---@return boolean
function M.is_authenticated(callback)
  local current_time = vim.loop.now()

  if not c.initialized then
    return false
  end

  if auth_cache.authenticated ~= nil then
    local ttl = get_cache_ttl(auth_cache.authenticated)
    if (current_time - auth_cache.timestamp) < ttl then
      return auth_cache.authenticated
    end
  end

  local client = c.get()
  if not client then
    return false
  end

  check_status(client, callback)

  return auth_cache.authenticated or false
end

return M
