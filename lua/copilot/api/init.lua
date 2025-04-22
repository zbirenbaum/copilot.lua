local logger = require("copilot.logger")
local utils = require("copilot.client.utils")
---@class CopilotApi
local M = {
  ---@deprecated
  status = require("copilot.status"),
}

---@param callback? fun(err: any|nil, data: table, ctx: table): nil
---@return any|nil err
---@return any data
---@return table ctx
function M.request(client, method, params, callback)
  logger.trace("api request:", method, params)
  -- hack to convert empty table to json object,
  -- empty table is convert to json array by default.
  params._ = true

  local bufnr = params.bufnr
  params.bufnr = nil

  if callback then
    return utils.wrap(client):request(method, params, callback, bufnr)
  end

  local co = coroutine.running()
  utils.wrap(client):request(method, params, function(err, data, ctx)
    coroutine.resume(co, err, data, ctx)
  end, bufnr)
  return coroutine.yield()
end

---@return boolean sent
function M.notify(client, method, params)
  logger.trace("api notify:", method, params)
  return utils.wrap(client):notify(method, params)
end

---@alias copilot_editor_info { name: string, version: string }
---@alias copilot_editor_plugin_info { name: string, version: string }

---@alias copilot_settings_http { proxy: string, proxyStrictSSL: boolean, proxyKerberosServicePrincipal?: string }
---@alias github_settings_telemetry { telemetryLevel: string }
---@alias copilot_settings_github-enterprise { uri: string }
---@alias copilot_settings { http?: copilot_settings_http, telemetry: github_settings_telemetry, github-enterprise?: copilot_settings_github-enterprise }

---@alias copilot_workspace_selected_completion_model { selectedCompletionModel: string }
---@alias copilot_workspace_copilot { copilot: copilot_workspace_copilot }
---@alias copilot_workspace_configuration { enableAutoCompletions: boolean, disabledLanguages: string[], github: copilot_workspace_configuration }
---@alias copilot_workspace_configurations { settings: copilot_workspace_configuration }

---@param params copilot_workspace_configurations
function M.notify_change_configuration(client, params)
  return M.notify(client, "workspace/didChangeConfiguration", params)
end

---@alias copilot_nofify_set_trace_params { value: 'off'|'messages'|'verbose' }

---@param params copilot_nofify_set_trace_params
function M.notify_set_trace(client, params)
  return M.notify(client, "$/setTrace", params)
end

---@alias copilot_check_status_params { options?: { localChecksOnly?: boolean } }
---@alias copilot_check_status_data { user?: string, status: 'OK'|'NotAuthorized'|'NoTelemetryConsent' }

---@param params? copilot_check_status_params
---@return any|nil err
---@return copilot_check_status_data data
---@return table ctx
function M.check_status(client, params, callback)
  if type(params) == "function" then
    callback = params
    params = {}
  end
  return M.request(client, "checkStatus", params or {}, callback)
end

---@alias copilot_sign_in_initiate_data { verificationUri?: string, userCode?: string }

---@return any|nil err
---@return copilot_sign_in_initiate_data data
---@return table ctx
function M.sign_in_initiate(client, callback)
  return M.request(client, "signInInitiate", {}, callback)
end

---@alias copilot_sign_in_confirm_params { userId: string }
---@alias copilot_sign_in_confirm_data { status: string, error: { message: string }, user: string }

---@param params copilot_sign_in_confirm_params
---@return any|nil err
---@return copilot_sign_in_confirm_data data
---@return table ctx
function M.sign_in_confirm(client, params, callback)
  return M.request(client, "signInConfirm", params, callback)
end

function M.sign_out(client, callback)
  return M.request(client, "signOut", {}, callback)
end

---@alias copilot_get_version_data { version: string }

---@return any|nil err
---@return copilot_get_version_data data
---@return table ctx
function M.get_version(client, callback)
  return M.request(client, "getVersion", {}, callback)
end

---@alias copilot_notify_accepted_params { uuid: string, acceptedLength?: integer }

---@param params copilot_notify_accepted_params
function M.notify_accepted(client, params, callback)
  return M.request(client, "notifyAccepted", params, callback)
end

---@alias copilot_notify_rejected_params { uuids: string[] }

---@param params copilot_notify_rejected_params
function M.notify_rejected(client, params, callback)
  return M.request(client, "notifyRejected", params, callback)
end

---@alias copilot_notify_shown_params { uuid: string }

---@param params copilot_notify_shown_params
function M.notify_shown(client, params, callback)
  return M.request(client, "notifyShown", params, callback)
end

---@alias copilot_get_completions_data_completion { displayText: string, position: { character: integer, line: integer }, range: { ['end']: { character: integer, line: integer }, start: { character: integer, line: integer } }, text: string, uuid: string, partial_text: string }
---@alias copilot_get_completions_data { completions: copilot_get_completions_data_completion[] }

---@return any|nil err
---@return copilot_get_completions_data data
---@return table ctx
function M.get_completions(client, params, callback)
  return M.request(client, "getCompletions", params, callback)
end

function M.get_completions_cycling(client, params, callback)
  return M.request(client, "getCompletionsCycling", params, callback)
end

---@return any|nil err
---@return integer data
---@return table ctx
function M.get_panel_completions(client, params, callback)
  return M.request(client, "getPanelCompletions", params, callback)
end

---@alias copilot_window_show_document { uri: string, external?: boolean, takeFocus?: boolean, selection?: boolean }
---@alias copilot_window_show_document_result { success: boolean }

return M
