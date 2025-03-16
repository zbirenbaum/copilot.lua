local mod = {}

---@param callback? fun(err: any|nil, data: table, ctx: table): nil
---@return any|nil err
---@return table data
---@return table ctx
function mod.request(client, method, params, callback)
  -- hack to convert empty table to json object,
  -- empty table is convert to json array by default.
  params._ = true

  local bufnr = params.bufnr
  params.bufnr = nil

  if callback then
    return client.request(method, params, callback, bufnr)
  end

  local co = coroutine.running()
  client.request(method, params, function(err, data, ctx)
    coroutine.resume(co, err, data, ctx)
  end, bufnr)
  return coroutine.yield()
end

---@return boolean sent
function mod.notify(client, method, params)
  return client.notify(method, params)
end

---@alias copilot_editor_info { name: string, version: string }
---@alias copilot_editor_plugin_info { name: string, version: string }
---@alias copilot_auth_provider { url: string }
---@alias copilot_network_proxy { host: string, port: integer, username?: string, password?: string, rejectUnauthorized?: boolean }
---@alias copilot_set_editor_info_params { editorInfo: copilot_editor_info, editorPluginInfo: copilot_editor_plugin_info, editorConfiguration: copilot_editor_configuration, networkProxy?: copilot_network_proxy, authProvider?: copilot_auth_provider }

---@param params copilot_set_editor_info_params
---@return any|nil err
---@return nil data
---@return table ctx
function mod.set_editor_info(client, params, callback)
  return mod.request(client, "setEditorInfo", params, callback)
end

---@alias copilot_editor_configuration { enableAutoCompletions: boolean, disabledLanguages: string[] }
---@alias copilot_notify_change_configuration_params { settings: copilot_editor_configuration  }

---@param params copilot_notify_change_configuration_params
function mod.notify_change_configuration(client, params)
  return mod.notify(client, "notifyChangeConfiguration", params)
end

---@alias copilot_check_status_params { options?: { localChecksOnly?: boolean } }
---@alias copilot_check_status_data { user?: string, status: 'OK'|'NotAuthorized'|'NoTelemetryConsent' }

---@param params? copilot_check_status_params
---@return any|nil err
---@return copilot_check_status_data data
---@return table ctx
function mod.check_status(client, params, callback)
  if type(params) == "function" then
    callback = params
    params = {}
  end
  return mod.request(client, "checkStatus", params or {}, callback)
end

---@alias copilot_sign_in_initiate_data { verificationUri?: string, userCode?: string }

---@return any|nil err
---@return copilot_sign_in_initiate_data data
---@return table ctx
function mod.sign_in_initiate(client, callback)
  return mod.request(client, "signInInitiate", {}, callback)
end

---@alias copilot_sign_in_confirm_params { userId: string }
---@alias copilot_sign_in_confirm_data { status: string, error: { message: string }, user: string }

---@param params copilot_sign_in_confirm_params
---@return any|nil err
---@return copilot_sign_in_confirm_data data
---@return table ctx
function mod.sign_in_confirm(client, params, callback)
  return mod.request(client, "signInConfirm", params, callback)
end

function mod.sign_out(client, callback)
  return mod.request(client, "signOut", {}, callback)
end

---@alias copilot_get_version_data { version: string }

---@return any|nil err
---@return copilot_get_version_data data
---@return table ctx
function mod.get_version(client, callback)
  return mod.request(client, "getVersion", {}, callback)
end

---@alias copilot_notify_accepted_params { uuid: string, acceptedLength?: integer }

---@param params copilot_notify_accepted_params
function mod.notify_accepted(client, params, callback)
  return mod.request(client, "notifyAccepted", params, callback)
end

---@alias copilot_notify_rejected_params { uuids: string[] }

---@param params copilot_notify_rejected_params
function mod.notify_rejected(client, params, callback)
  return mod.request(client, "notifyRejected", params, callback)
end

---@alias copilot_notify_shown_params { uuid: string }

---@param params copilot_notify_shown_params
function mod.notify_shown(client, params, callback)
  return mod.request(client, "notifyShown", params, callback)
end

---@alias copilot_get_completions_data_completion { displayText: string, position: { character: integer, line: integer }, range: { ['end']: { character: integer, line: integer }, start: { character: integer, line: integer } }, text: string, uuid: string }
---@alias copilot_get_completions_data { completions: copilot_get_completions_data_completion[] }

---@return any|nil err
---@return copilot_get_completions_data data
---@return table ctx
function mod.get_completions(client, params, callback)
  return mod.request(client, "getCompletions", params, callback)
end

function mod.get_completions_cycling(client, params, callback)
  return mod.request(client, "getCompletionsCycling", params, callback)
end

---@alias copilot_get_panel_completions_data { solutionCountTarget: integer }
---@alias copilot_panel_solution_data { panelId: string, completionText: string, displayText: string, range: { ['end']: { character: integer, line: integer }, start: { character: integer, line: integer } }, score: number, solutionId: string }
---@alias copilot_panel_on_solution_handler fun(result: copilot_panel_solution_data): nil
---@alias copilot_panel_solutions_done_data { panelId: string, status: 'OK'|'Error', message?: string }
---@alias copilot_panel_on_solutions_done_handler fun(result: copilot_panel_solutions_done_data): nil

---@return any|nil err
---@return copilot_get_panel_completions_data data
---@return table ctx
function mod.get_panel_completions(client, params, callback)
  return mod.request(client, "getPanelCompletions", params, callback)
end

local panel = {
  callback = {
    PanelSolution = {},
    PanelSolutionsDone = {},
  },
}

panel.handlers = {
  ---@param result copilot_panel_solution_data
  PanelSolution = function(_, result)
    if panel.callback.PanelSolution[result.panelId] then
      panel.callback.PanelSolution[result.panelId](result)
    end
  end,

  ---@param result copilot_panel_solutions_done_data
  PanelSolutionsDone = function(_, result)
    if panel.callback.PanelSolutionsDone[result.panelId] then
      panel.callback.PanelSolutionsDone[result.panelId](result)
    end
  end,
}

---@param panelId string
---@param handlers { on_solution: copilot_panel_on_solution_handler, on_solutions_done: copilot_panel_on_solutions_done_handler }
function mod.register_panel_handlers(panelId, handlers)
  assert(type(panelId) == "string", "missing panelId")
  panel.callback.PanelSolution[panelId] = handlers.on_solution
  panel.callback.PanelSolutionsDone[panelId] = handlers.on_solutions_done
end

---@param panelId string
function mod.unregister_panel_handlers(panelId)
  assert(type(panelId) == "string", "missing panelId")
  panel.callback.PanelSolution[panelId] = nil
  panel.callback.PanelSolutionsDone[panelId] = nil
end

---@alias copilot_status_notification_data { status: ''|'Normal'|'InProgress'|'Warning', message: string }

local status = {
  client_id = nil,
  ---@type copilot_status_notification_data
  data = {
    status = "",
    message = "",
  },
  callback = {},
}

status.handlers = {
  ---@param result copilot_status_notification_data
  ---@param ctx { client_id: integer, method: string }
  statusNotification = function(_, result, ctx)
    status.client_id = ctx.client_id
    status.data = result

    for callback in pairs(status.callback) do
      callback(status.data)
    end
  end,
}

---@param handler fun(data: copilot_status_notification_data): nil
function mod.register_status_notification_handler(handler)
  status.callback[handler] = true
  handler(status.data)
end

---@param handler fun(data: copilot_status_notification_data): nil
function mod.unregister_status_notification_handler(handler)
  status.callback[handler] = nil
end

---@alias copilot_open_url_data { target: string }

mod.handlers = {
  PanelSolution = panel.handlers.PanelSolution,
  PanelSolutionsDone = panel.handlers.PanelSolutionsDone,
  statusNotification = status.handlers.statusNotification,
  ---@param result copilot_open_url_data
  ["copilot/openURL"] = function(_, result)
    local success, _ = pcall(vim.ui.open, result.target)
    if not success then
      if vim.ui.open ~= nil then
        vim.api.nvim_echo({
          { "copilot/openURL" },
          { vim.inspect({ _, result }) },
          { "\n", "NONE" },
        }, true, {})
        error("Unsupported OS: vim.ui.open exists but failed to execute.")
      else
        vim.api.nvim_echo({
          { "copilot/openURL" },
          { vim.inspect({ _, result }) },
          { "\n", "NONE" },
        }, true, {})
        error("Unsupported Version: vim.ui.open requires Neovim > 0.10")
      end
    end
  end,
}

mod.panel = panel
mod.status = status

return mod
