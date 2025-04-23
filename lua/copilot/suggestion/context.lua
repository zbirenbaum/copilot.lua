local M = {
  context = {},
  hide_during_completion = true,
  auto_trigger = true,
}
local copilot = require("copilot")
local logger = require("copilot.logger")
local c = require("copilot.client")
local api = require("copilot.api")
local util = require("copilot.util")
local client_utils = require("copilot.client.utils")
local utils = require("copilot.suggestion.utils")
local timer = require("copilot.suggestion.timer")

local function is_enabled()
  return c.buf_is_attached(0)
end

---@param bufnr? integer
---@return copilot_suggestion_context
function M.get_ctx(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ctx = M.context[bufnr]
  logger.trace("suggestion context", ctx)
  if not ctx then
    ctx = {}
    M.context[bufnr] = ctx
    logger.trace("suggestion new context", ctx)
  end
  return ctx
end

---@param ctx? copilot_suggestion_context
function M.cancel_inflight_requests(ctx)
  logger.trace("suggestion cancel inflight requests", ctx)
  ctx = ctx or M.get_ctx()

  utils.with_client(function(client)
    if ctx.first then
      client_utils.wrap(client):cancel_request(ctx.first)
      ctx.first = nil
      logger.trace("suggestion cancel first request")
    end
    if ctx.cycling then
      client_utils.wrap(client):cancel_request(ctx.cycling)
      ctx.cycling = nil
      logger.trace("suggestion cancel cycling request")
    end
  end)
end

---@param ctx? copilot_suggestion_context
function M.clear(ctx)
  logger.trace("suggestion clear", ctx)
  ctx = ctx or M.get_ctx()
  timer.stop_timer()
  M.cancel_inflight_requests(ctx)
  require("copilot.suggestion.preview").update_preview(ctx)
  M.reset_ctx(ctx)
end

---@param idx integer
---@param new_line integer
---@param new_end_col integer
---@param bufnr? integer
function M.update_ctx_suggestion_position(idx, new_line, new_end_col, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.context[bufnr] then
    return
  end

  if not M.context[bufnr].suggestions[idx] then
    return
  end

  local suggestion = M.context[bufnr].suggestions[idx]
  suggestion.range["start"].line = new_line
  suggestion.range["start"].character = 0
  suggestion.range["end"].line = new_line
  suggestion.range["end"].character = new_end_col
end

---@param idx integer
---@param text string
---@param bufnr? integer
function M.set_ctx_suggestion_text(idx, text, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.context[bufnr] then
    return
  end

  if not M.context[bufnr].suggestions[idx] then
    return
  end

  local suggestion = M.context[bufnr].suggestions[idx]
  local end_offset = #suggestion.text - #text
  suggestion.text = text
  suggestion.range["end"].character = suggestion.range["end"].character - end_offset
  M.context[bufnr].suggestions[idx] = suggestion
end

---@param ctx copilot_suggestion_context
function M.reset_ctx(ctx)
  logger.trace("suggestion reset context", ctx)
  ctx.first = nil
  ctx.cycling = nil
  ctx.cycling_callbacks = nil
  ctx.params = nil
  ctx.suggestions = nil
  ctx.choice = nil
  ctx.shown_choices = nil
  ctx.accepted_partial = nil
end

function M.schedule(ctx)
  if not is_enabled() or not c.initialized then
    M.clear()
    return
  end
  logger.trace("suggestion schedule", ctx)

  if timer.copilot_timer then
    M.cancel_inflight_requests(ctx)
    timer.stop_timer()
  end

  require("copilot.suggestion.preview").update_preview(ctx)
  local bufnr = vim.api.nvim_get_current_buf()
  timer.copilot_timer = vim.fn.timer_start(copilot.debounce, function(curr_timer)
    logger.trace("suggestion schedule timer", bufnr)
    M.trigger(bufnr, curr_timer)
  end)
end

---@param bufnr? integer
function M.reject(bufnr)
  local ctx = M.get_ctx(bufnr)
  if not ctx.shown_choices then
    return
  end

  local uuids = vim.tbl_keys(ctx.shown_choices)
  if #uuids > 0 then
    utils.with_client(function(client)
      api.notify_rejected(client, { uuids = uuids }, function() end)
    end)
    ctx.shown_choices = {}
  end
end

---@param ctx? copilot_suggestion_context
---@return copilot_get_completions_data_completion|nil
function M.get_current_suggestion(ctx)
  logger.trace("suggestion get current suggestion", ctx)
  ctx = ctx or M.get_ctx()
  logger.trace("suggestion current suggestion", ctx)

  local ok, choice = pcall(function()
    if
      not vim.fn.mode():match("^[iR]")
      or (M.hide_during_completion and vim.fn.pumvisible() == 1)
      or vim.b.copilot_suggestion_hidden
      or not ctx.suggestions
      or #ctx.suggestions == 0
    then
      return nil
    end

    local choice = ctx.suggestions[ctx.choice]
    if not choice or not choice.range or choice.range.start.line ~= vim.fn.line(".") - 1 then
      return nil
    end

    return choice
  end)

  if ok then
    return choice
  end

  return nil
end

function M.should_auto_trigger()
  if vim.b.copilot_suggestion_auto_trigger == nil then
    return M.auto_trigger
  end
  return vim.b.copilot_suggestion_auto_trigger
end

---@param callback fun(err: any|nil, data: copilot_get_completions_data): nil
local function complete(callback)
  logger.trace("suggestion complete")
  timer.stop_timer()

  local ctx = M.get_ctx()
  local params = util.get_doc_params()

  if not vim.deep_equal(ctx.params, params) then
    utils.with_client(function(client)
      local _, id = api.get_completions(client, params, callback)
      ctx.params = params
      ctx.first = id --[[@as integer]]
    end)
  end
end

---@param err any|nil
---@param data copilot_get_completions_data
local function handle_trigger_request(err, data)
  if err then
    logger.error(err)
  end
  logger.trace("suggestion handle trigger request", data)
  local ctx = M.get_ctx()
  ctx.suggestions = data and data.completions or {}
  ctx.choice = 1
  ctx.shown_choices = {}
  require("copilot.suggestion.preview").update_preview()
end

---@param bufnr integer
---@param trigger_timer any
function M.trigger(bufnr, trigger_timer)
  logger.trace("suggestion trigger", bufnr)
  local _timer = timer.copilot_timer
  timer.copilot_timer = nil

  if bufnr ~= vim.api.nvim_get_current_buf() or (_timer ~= nil and trigger_timer ~= _timer) or vim.fn.mode() ~= "i" then
    logger.trace("suggestion trigger, not in insert mode")
    return
  end

  complete(handle_trigger_request)
end

return M
