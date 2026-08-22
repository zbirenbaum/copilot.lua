local M = {}

local api = require("copilot.api")
local auth = require("copilot.auth")
local c = require("copilot.client")
local config = require("copilot.config")
local installer = require("copilot.lsp.installer")
local nodejs = require("copilot.lsp.nodejs")
local release = require("copilot.lsp.release")

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

local function command_string(command)
  if type(command) == "table" then
    return table.concat(command, " ")
  end
  return command
end

function M.check()
  start("{copilot.lua}")
  info("{copilot.lua} GitHub Copilot plugin for Neovim")

  start("Copilot Dependencies")

  local server_config = config.server
  local server_type = server_config and server_config.type or "binary"
  info("server mode: " .. server_type)
  info("pinned version: " .. release.version)
  if server_config.custom_server_filepath then
    info("custom server path: " .. server_config.custom_server_filepath)
    info("installation bypassed for custom server path")
  else
    info("cache: `" .. installer.get_cache_root() .. "`")

    local target, target_error = installer.resolve_target(server_type)
    if target then
      info("target: " .. target)
    else
      error("native target unavailable: " .. target_error)
      info('Configure `server = { type = "nodejs" }` for the Node.js fallback')
    end
  end
  local installer_status = installer.get_status()
  info("installer state: " .. installer_status.state)
  if installer_status.error then
    info("installer error: " .. installer_status.error)
  end

  if server_type == "nodejs" then
    local node_command = config.copilot_node_command or "node"
    info("Node.js command: " .. command_string(node_command))
    local node_version, node_version_error = nodejs.get_node_version_for_command(node_command)
    if node_version_error then
      error("Node.js command failed: " .. node_version_error)
    else
      ok("Node.js found: " .. node_version)
    end
  end

  start("Copilot Authentication")

  local github_token = os.getenv("GITHUB_COPILOT_TOKEN")
  local gh_token = os.getenv("GH_COPILOT_TOKEN")
  if github_token or gh_token then
    ok("Environment token found: " .. (github_token and "`GITHUB_COPILOT_TOKEN`" or "`GH_COPILOT_TOKEN`"))
  else
    info("No environment token set (`GITHUB_COPILOT_TOKEN` or `GH_COPILOT_TOKEN`)")
  end

  local config_path = auth.find_config_path()
  local auth_db_path = (config_path or "unknown") .. "/github-copilot/auth.db"
  if config_path and vim.fn.filereadable(auth_db_path) == 1 then
    ok("Local credentials found")
    info("Location: `" .. auth_db_path .. "`")
  else
    info("No local credentials found")
    info("Expected location: `" .. auth_db_path .. "`")
    info("Run `:Copilot auth` to authenticate")
  end

  local client = c.get()
  if not client then
    if c.is_disabled() then
      error("Copilot is disabled")
      if server_type == "nodejs" then
        info("Check Node.js installation (version 22+ required)")
      else
        info("Check the native Copilot server target and installer status above")
      end
      info("Run `:messages` for details or check the log file")
    else
      error("Copilot LSP client not available")
      info("Check that the plugin is properly loaded and configured")
      info("Or restart Neovim if the plugin was just installed")
    end
    return
  end

  start("Copilot LSP Status")
  ok("LSP client is available and running")
  info("Client ID: " .. tostring(client.id))

  vim.wait(2000, function()
    return c.initialized
  end, 50)

  if not c.initialized then
    warn("LSP client is running but has not finished initializing")
    info("This is not an authentication problem, retry `:checkhealth copilot` once Copilot is active")
  else
    local done = false
    local status_err, status = nil, nil
    api.check_status(
      client,
      {},
      ---@param status_data copilot_check_status_data
      function(err, status_data)
        status_err, status = err, status_data
        done = true
      end
    )
    vim.wait(5000, function()
      return done
    end, 50)

    if not done then
      warn("LSP authentication status: no response from server (timed out)")
    elseif status_err then
      warn("LSP authentication status: " .. tostring(status_err))
    elseif status and status.user then
      ok("LSP authentication status: authenticated as `" .. status.user .. "`")
    else
      warn("LSP authentication status: not authenticated (status: " .. (status and status.status or "unknown") .. ")")
      info("Run `:Copilot auth signin` to authenticate")
    end
  end
  info("For detailed authentication status, run `:Copilot status`")

  start("Copilot Configuration")
  local suggestion_config = config.suggestion
  if suggestion_config and suggestion_config.enabled ~= false then
    ok("Suggestions enabled")
    if suggestion_config.auto_trigger ~= false then
      info("Auto-trigger: enabled")
    else
      info("Auto-trigger: disabled (manual trigger only)")
    end
  else
    warn("Suggestions disabled in configuration")
    info("Enable with `suggestion = { enabled = true }` in setup()")
  end

  local panel_config = config.panel
  if panel_config and panel_config.enabled ~= false then
    ok("Panel enabled")
    info("Panel Keybinding: " .. (panel_config.keymap and panel_config.keymap.open or "<M-CR>"))
  else
    info("Panel disabled in configuration")
    info("Enable with `panel = { enabled = true }` in setup()")
  end

  local logger_config = config.logger
  if logger_config then
    info("Log file: " .. (logger_config.file or "not set"))
  end
end

return M
