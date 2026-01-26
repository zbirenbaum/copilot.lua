local c = require("copilot.client")
local api = require("copilot.api")
local config = require("copilot.config")
local logger = require("copilot.logger")

local M = {}

--- Runtime override of the model (not persisted to user config)
--- When set, this takes precedence over config.copilot_model
---@type string|nil
M.selected_model = nil

--- Get the currently active model ID
---@return string
function M.get_current_model()
  return M.selected_model or config.copilot_model or ""
end

--- Filter models that support completions
---@param models copilot_model[]
---@return copilot_model[]
local function get_completion_models(models)
  return vim.tbl_filter(function(m)
    return vim.tbl_contains(m.scopes or {}, "completion")
  end, models)
end

--- Format a model for display
---@param model copilot_model
---@return string
local function format_model(model, show_id)
  local parts = { model.modelName }
  if show_id then
    table.insert(parts, "[" .. model.id .. "]")
  end
  local annotations = {}

  if model.default then
    table.insert(annotations, "default")
  end
  if model.preview then
    table.insert(annotations, "preview")
  end

  if #annotations > 0 then
    table.insert(parts, "(" .. table.concat(annotations, ", ") .. ")")
  end

  return table.concat(parts, " ")
end

--- Apply the selected model by notifying the LSP server
---@param model_id string
local function apply_model(model_id)
  M.selected_model = model_id

  local client = c.get()
  if client then
    local utils = require("copilot.client.utils")
    local configurations = utils.get_workspace_configurations()
    api.notify_change_configuration(client, configurations)
    logger.debug("Model changed to: " .. model_id)
  end
end

--- Interactive model selection using vim.ui.select
---@param opts? { force?: boolean, args?: string }
function M.select(opts)
  opts = opts or {}

  local client = c.get()
  if not client then
    logger.notify("Copilot client not running")
    return
  end

  coroutine.wrap(function()
    local err, models = api.get_models(client)
    if err then
      logger.notify("Failed to get models: " .. vim.inspect(err))
      return
    end

    if not models or #models == 0 then
      logger.notify("No models available")
      return
    end

    local completion_models = get_completion_models(models)
    if #completion_models == 0 then
      logger.notify("No completion models available")
      return
    end

    local current_model = M.get_current_model()
    if #completion_models == 1 then
      local model = completion_models[1]
      local model_name = format_model(model)
      logger.notify("Only one completion model available: " .. model_name)
      if model.id ~= current_model then
        apply_model(model.id)
        logger.notify("Copilot model set to: " .. model_name)
      else
        logger.notify("Copilot model is already set to: " .. model_name)
      end
      return
    end

    -- Sort models: default first, then by name
    table.sort(completion_models, function(a, b)
      if a.default and not b.default then
        return true
      end
      if b.default and not a.default then
        return false
      end
      return a.modelName < b.modelName
    end)

    vim.ui.select(completion_models, {
      prompt = "Select Copilot completion model:",
      format_item = function(model)
        local display = format_model(model)
        if model.id == current_model then
          display = display .. " [current]"
        end
        return display
      end,
    }, function(selected)
      if not selected then
        return
      end

      apply_model(selected.id)
      logger.notify("Copilot model set to: " .. format_model(selected))
    end)
  end)()
end

--- List available completion models
---@param opts? { force?: boolean, args?: string }
function M.list(opts)
  opts = opts or {}

  local client = c.get()
  if not client then
    logger.notify("Copilot client not running")
    return
  end

  coroutine.wrap(function()
    local err, models = api.get_models(client)
    if err then
      logger.notify("Failed to get models: " .. vim.inspect(err))
      return
    end

    if not models or #models == 0 then
      logger.notify("No models available")
      return
    end

    local completion_models = get_completion_models(models)
    if #completion_models == 0 then
      logger.notify("No completion models available")
      return
    end

    local current_model = M.get_current_model()
    local lines = { "Available completion models:" }

    for _, model in ipairs(completion_models) do
      local line = "  " .. format_model(model, true)
      if model.id == current_model then
        line = line .. " <- current"
      end
      table.insert(lines, line)
    end

    logger.notify(table.concat(lines, "\n"))
  end)()
end

--- Show the current model
---@param opts? { force?: boolean, args?: string }
function M.get(opts)
  opts = opts or {}

  local current = M.get_current_model()
  if current == "" then
    logger.notify("No model configured (using server default)")
  else
    logger.notify("Current model: " .. current)
  end
end

--- Set the model programmatically
---@param opts { model?: string, force?: boolean, args?: string }
function M.set(opts)
  opts = opts or {}

  local model_id = opts.model or opts.args
  if not model_id or model_id == "" then
    logger.notify("Usage: :Copilot model set <model-id>")
    return
  end

  apply_model(model_id)
  logger.notify("Copilot model set to: " .. model_id)
end

--- Validate the currently configured model against available models
--- Called on startup to warn if the configured model is invalid
function M.validate_current()
  local configured_model = config.copilot_model
  if not configured_model or configured_model == "" then
    return -- No model configured, nothing to validate
  end

  local client = c.get()
  if not client then
    return
  end

  coroutine.wrap(function()
    local err, models = api.get_models(client)
    if err then
      logger.debug("Failed to validate model: " .. vim.inspect(err))
      return
    end

    if not models or #models == 0 then
      return
    end

    local completion_models = get_completion_models(models)
    local valid_ids = vim.tbl_map(function(m)
      return m.id
    end, completion_models)

    if not vim.tbl_contains(valid_ids, configured_model) then
      local valid_list = table.concat(valid_ids, ", ")
      logger.warn(
        string.format(
          "Configured copilot_model '%s' is not a valid completion model. Available: %s",
          configured_model,
          valid_list
        )
      )
    else
      logger.debug("Configured model '" .. configured_model .. "' is valid")
    end
  end)()
end

return M
