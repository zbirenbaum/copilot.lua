local M = {}

local api = require("copilot.api")
local auth = require("copilot.auth")
local c = require("copilot.client")
local config = require("copilot.config")

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

function M.check()
  start("{copilot.lua}")
  info("{copilot.lua} GitHub Copilot plugin for Neovim")

  start("Copilot Dependencies")

  if vim.fn.executable("node") == 1 then
    local node_version = vim.fn.system("node --version"):gsub("\n", "")
    ok("`node` found: " .. node_version)
  else
    error("`node` not found in PATH")
    info("Install Node.js from https://nodejs.org")
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
      info("Check Node.js installation (version 22+ required)")
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
