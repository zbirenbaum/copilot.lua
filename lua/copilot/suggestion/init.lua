local api = require("copilot.api")
local auth = require("copilot.auth")
local c = require("copilot.client")
local config = require("copilot.config")
local hl_group = require("copilot.highlight").group
local util = require("copilot.util")
local logger = require("copilot.logger")
local suggestion_util = require("copilot.suggestion.utils")
local utils = require("copilot.client.utils")
local keymaps = require("copilot.keymaps")

local M = {}

---@alias copilot_suggestion_context { first?: integer, cycling?: integer, cycling_callbacks?: (fun(ctx: copilot_suggestion_context):nil)[], params?: table, suggestions?: copilot_get_completions_data_completion[], choice?: integer, shown_choices?: table<string, true>, accepted_partial?: boolean }

local copilot = {
  setup_done = false,

  augroup = "copilot.suggestion",
  ns_id = vim.api.nvim_create_namespace("copilot.suggestion"),
  extmark_id = 1,

  _copilot_timer = nil,
  context = {},

  auto_trigger = false,
  hide_during_completion = true,
  debounce = 75,
}

local ignore_next_cursor_moved = false

local function with_client(fn)
  local client = c.get()
  if client then
    fn(client)
  end
end

---@return boolean
local function is_enabled()
  return c.buf_is_attached(0)
end

---@return boolean
local function should_auto_trigger()
  if vim.b.copilot_suggestion_auto_trigger == nil then
    return copilot.auto_trigger
  end
  return vim.b.copilot_suggestion_auto_trigger
end

---@param bufnr? integer
---@return copilot_suggestion_context
local function get_ctx(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ctx = copilot.context[bufnr]

  if not ctx then
    ctx = {}
    copilot.context[bufnr] = ctx
    logger.trace("suggestion new context")
  end

  return ctx
end

---@param idx integer
---@param new_line integer
---@param new_end_col integer
---@param bufnr? integer
local function update_ctx_suggestion_position(idx, new_line, new_end_col, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not copilot.context[bufnr] then
    return
  end

  if not copilot.context[bufnr].suggestions[idx] then
    return
  end

  local suggestion = copilot.context[bufnr].suggestions[idx]
  suggestion.range["start"].line = new_line
  suggestion.range["start"].character = 0
  suggestion.range["end"].line = new_line
  suggestion.range["end"].character = new_end_col
end

---@param idx integer
---@param text string
---@param bufnr? integer
local function set_ctx_suggestion_text(idx, text, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not copilot.context[bufnr] then
    return
  end

  if not copilot.context[bufnr].suggestions[idx] then
    return
  end

  local suggestion = copilot.context[bufnr].suggestions[idx]
  local end_offset = #suggestion.text - #text
  suggestion.text = text
  suggestion.range["end"].character = suggestion.range["end"].character - end_offset
  copilot.context[bufnr].suggestions[idx] = suggestion
end

---@param ctx copilot_suggestion_context
local function reset_ctx(ctx)
  logger.trace("suggestion reset context")
  ctx.first = nil
  ctx.cycling = nil
  ctx.cycling_callbacks = nil
  ctx.params = nil
  ctx.suggestions = nil
  ctx.choice = nil
  ctx.shown_choices = nil
  ctx.accepted_partial = nil
end

---@param bufnr integer
function M.set_keymap(bufnr)
  if not config.suggestion.enabled then
    return
  end

  local keymap = config.suggestion.keymap or {}

  keymaps.register_keymap_with_passthrough("i", keymap.accept, function()
    local ctx = get_ctx()
    if (config.suggestion.trigger_on_accept and not ctx.first) or M.is_visible() then
      M.accept()
      return true
    end

    return false
  end, "[copilot] accept suggestion", bufnr)

  keymaps.register_keymap("i", keymap.accept_word, M.accept_word, "[copilot] accept suggestion (word)", bufnr)
  keymaps.register_keymap("i", keymap.accept_line, M.accept_line, "[copilot] accept suggestion (line)", bufnr)
  keymaps.register_keymap("i", keymap.next, M.next, "[copilot] next suggestion", bufnr)
  keymaps.register_keymap("i", keymap.prev, M.prev, "[copilot] prev suggestion", bufnr)

  keymaps.register_keymap_with_passthrough("i", keymap.dismiss, function()
    if M.is_visible() then
      M.dismiss()
      return true
    end

    return false
  end, "[copilot] dismiss suggestion", bufnr)
end

---@param bufnr integer
function M.unset_keymap(bufnr)
  if not config.suggestion.enabled then
    return
  end

  local keymap = config.suggestion.keymap or {}
  keymaps.unset_keymap_if_exists("i", keymap.accept, bufnr)
  keymaps.unset_keymap_if_exists("i", keymap.accept_word, bufnr)
  keymaps.unset_keymap_if_exists("i", keymap.accept_line, bufnr)
  keymaps.unset_keymap_if_exists("i", keymap.next, bufnr)
  keymaps.unset_keymap_if_exists("i", keymap.prev, bufnr)
  keymaps.unset_keymap_if_exists("i", keymap.dismiss, bufnr)
end

local function stop_timer()
  if copilot._copilot_timer then
    logger.trace("suggestion stop timer")
    vim.fn.timer_stop(copilot._copilot_timer)
    copilot._copilot_timer = nil
  end
end

---@param bufnr? integer
local function reject(bufnr)
  local ctx = get_ctx(bufnr)
  if not ctx.shown_choices then
    return
  end

  local uuids = vim.tbl_keys(ctx.shown_choices)
  if #uuids > 0 then
    with_client(function(client)
      api.notify_rejected(client, { uuids = uuids }, function() end)
    end)
    ctx.shown_choices = {}
  end
end

---@param ctx? copilot_suggestion_context
local function cancel_inflight_requests(ctx)
  logger.trace("suggestion cancel inflight requests")
  ctx = ctx or get_ctx()

  with_client(function(client)
    if ctx.first then
      utils.wrap(client):cancel_request(ctx.first)
      ctx.first = nil
      logger.trace("suggestion cancel first request")
    end
    if ctx.cycling then
      utils.wrap(client):cancel_request(ctx.cycling)
      ctx.cycling = nil
      logger.trace("suggestion cancel cycling request")
    end
  end)
end

function M.clear_preview()
  logger.trace("suggestion clear preview")
  vim.api.nvim_buf_del_extmark(0, copilot.ns_id, copilot.extmark_id)
end

---@param ctx? copilot_suggestion_context
---@return copilot_get_completions_data_completion?
local function get_current_suggestion(ctx)
  logger.trace("suggestion get current suggestion")
  ctx = ctx or get_ctx()
  logger.trace("suggestion current suggestion")

  local ok, choice = pcall(function()
    if
      not vim.fn.mode():match("^[iR]")
      or (copilot.hide_during_completion and vim.fn.pumvisible() == 1)
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

---@param ctx? copilot_suggestion_context
function M.update_preview(ctx)
  ctx = ctx or get_ctx()
  logger.trace("suggestion update preview", ctx)

  local suggestion = get_current_suggestion(ctx)
  local displayLines = suggestion and vim.split(suggestion.displayText, "\n", { plain = true }) or {}

  M.clear_preview()

  if not suggestion or #displayLines == 0 then
    return
  end

  local annot = ""
  if ctx.cycling_callbacks then
    annot = "(1/…)"
  elseif ctx.cycling then
    annot = "(" .. ctx.choice .. "/" .. #ctx.suggestions .. ")"
  end

  local cursor_col = vim.fn.col(".")
  local cursor_line = vim.fn.line(".") - 1
  local current_line = vim.api.nvim_buf_get_lines(0, cursor_line, cursor_line + 1, false)[1]
  local text_after_cursor = string.sub(current_line, cursor_col)

  displayLines[1] =
    string.sub(string.sub(suggestion.text, 1, (string.find(suggestion.text, "\n", 1, true) or 0) - 1), cursor_col)

  local suggestion_line1 = displayLines[1]

  if #displayLines == 1 then
    suggestion_line1 = suggestion_util.remove_common_suffix(text_after_cursor, suggestion_line1)
    local suggest_text = suggestion_util.remove_common_suffix(text_after_cursor, suggestion.text)
    set_ctx_suggestion_text(ctx.choice, suggest_text)
  end

  local has_control_chars = string.find(suggestion_line1, "%c") ~= nil or #displayLines > 1

  local extmark = {
    id = copilot.extmark_id,
    virt_text = { { suggestion_line1, hl_group.CopilotSuggestion } },
    -- inline does not support system control characters
    virt_text_pos = has_control_chars and "eol" or "inline",
    hl_mode = "replace",
  }

  if has_control_chars then
    extmark.virt_text_win_col = vim.fn.virtcol(".") - 1
  end

  if #displayLines > 1 then
    extmark.virt_lines = {}
    for i = 2, #displayLines do
      extmark.virt_lines[i - 1] = { { displayLines[i], hl_group.CopilotSuggestion } }
    end
    if #annot > 0 then
      extmark.virt_lines[#displayLines] = { { " " }, { annot, hl_group.CopilotAnnotation } }
    end
  elseif #annot > 0 then
    extmark.virt_text[2] = { " " }
    extmark.virt_text[3] = { annot, hl_group.CopilotAnnotation }
  end

  vim.api.nvim_buf_set_extmark(0, copilot.ns_id, vim.fn.line(".") - 1, cursor_col - 1, extmark)

  if config.suggestion.suggestion_notification then
    vim.schedule(function()
      config.suggestion.suggestion_notification(extmark.virt_text, extmark.virt_lines or {})
    end)
  end

  if not ctx.shown_choices[suggestion.uuid] then
    ctx.shown_choices[suggestion.uuid] = true
    with_client(function(client)
      api.notify_shown(client, { uuid = suggestion.uuid }, function() end)
    end)
  end
end

---@param ctx? copilot_suggestion_context
local function clear(ctx)
  logger.trace("suggestion clear")
  ctx = ctx or get_ctx()
  stop_timer()
  cancel_inflight_requests(ctx)
  M.update_preview(ctx)
  reset_ctx(ctx)
end

---@param callback fun(err: any|nil, data: copilot_get_completions_data): nil
local function complete(callback)
  logger.trace("suggestion complete")
  stop_timer()

  local ctx = get_ctx()
  local params = util.get_doc_params()

  if not vim.deep_equal(ctx.params, params) then
    with_client(function(client)
      local _, id = api.get_completions(client, params, callback)
      ctx.params = params
      ctx.first = id --[[@as integer]]
    end)
  end
end

---@param data copilot_get_completions_data
local function handle_trigger_request(err, data)
  if err then
    logger.error(err)
  end
  logger.trace("suggestion handle trigger request", data)
  local ctx = get_ctx()
  ctx.suggestions = data and data.completions or {}
  ctx.choice = 1
  ctx.shown_choices = {}
  M.update_preview()
end

local function trigger(bufnr, timer)
  logger.trace("suggestion trigger", bufnr)
  local _timer = copilot._copilot_timer
  copilot._copilot_timer = nil

  if bufnr ~= vim.api.nvim_get_current_buf() or (_timer ~= nil and timer ~= _timer) or vim.fn.mode() ~= "i" then
    logger.trace("suggestion trigger, not in insert mode")
    return
  end

  complete(handle_trigger_request)
end

---@param ctx copilot_suggestion_context
local function get_suggestions_cycling_callback(ctx, err, data)
  logger.trace("suggestion get suggestions cycling callback", data)
  local callbacks = ctx.cycling_callbacks or {}
  ctx.cycling_callbacks = nil

  if err then
    logger.error(err)
    return
  end

  if not ctx.suggestions then
    return
  end

  local seen = {}

  for _, suggestion in ipairs(ctx.suggestions) do
    seen[suggestion.text] = true
  end

  for _, suggestion in ipairs(data.completions or {}) do
    if not seen[suggestion.text] then
      table.insert(ctx.suggestions, suggestion)
      seen[suggestion.text] = true
    end
  end

  for _, callback in ipairs(callbacks) do
    callback(ctx)
  end
end

---@param callback fun(ctx: copilot_suggestion_context): nil
---@param ctx copilot_suggestion_context
local function get_suggestions_cycling(callback, ctx)
  logger.trace("suggestion get suggestions cycling", ctx)

  if ctx.cycling_callbacks then
    table.insert(ctx.cycling_callbacks, callback)
    return
  end

  if ctx.cycling then
    callback(ctx)
    return
  end

  if ctx.suggestions then
    ctx.cycling_callbacks = { callback }
    with_client(function(client)
      local _, id = api.get_completions_cycling(client, ctx.params, function(err, data)
        get_suggestions_cycling_callback(ctx, err, data)
      end)
      ctx.cycling = id --[[@as integer]]
      M.update_preview(ctx)
    end)
  end
end

---@param bufnr? integer
local function schedule(bufnr)
  local function is_authenticated()
    return auth.is_authenticated(function()
      schedule(bufnr)
    end)
  end

  -- We do not want to solve auth.is_authenticated() unless the others are true
  if not is_enabled() or not c.initialized or not is_authenticated() then
    clear()
    return
  end

  logger.trace("suggestion schedule")

  if copilot._copilot_timer then
    cancel_inflight_requests()
    stop_timer()
  end

  M.update_preview()
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  copilot._copilot_timer = vim.fn.timer_start(copilot.debounce, function(timer)
    logger.trace("suggestion schedule timer", bufnr)
    trigger(bufnr, timer)
  end)
end

---@param bufnr? integer
local function request_suggestion(bufnr)
  logger.trace("suggestion request")
  c.buf_attach(false, bufnr)
  schedule(bufnr)
end

---@param bufnr? integer
local function request_suggestion_when_auto_trigger(bufnr)
  if not should_auto_trigger() then
    return
  end

  request_suggestion(bufnr)
end

function M.has_next()
  local ctx = get_ctx()

  -- no completions at all
  if not ctx.suggestions or #ctx.suggestions == 0 then
    return false
  end

  return (ctx.choice < #ctx.suggestions or not ctx.cycling)
end

local function advance(count, ctx)
  if ctx ~= get_ctx() then
    return
  end

  ctx.choice = (ctx.choice + count) % #ctx.suggestions
  if ctx.choice < 1 then
    ctx.choice = #ctx.suggestions
  end

  M.update_preview(ctx)
end

---@param ctx copilot_suggestion_context
---@return boolean
function M.first_request_scheduled(ctx)
  if not ctx.first then
    logger.trace("suggestion, no first request")
    request_suggestion()
    return true
  end

  return false
end

function M.next()
  local ctx = get_ctx()
  logger.trace("suggestion next", ctx)

  if ctx.accepted_partial then
    reset_ctx(ctx)
  end

  if M.first_request_scheduled(ctx) then
    return
  end

  get_suggestions_cycling(function(context)
    advance(1, context)
  end, ctx)
end

function M.prev()
  local ctx = get_ctx()
  logger.trace("suggestion prev", ctx)

  if ctx.accepted_partial then
    reset_ctx(ctx)
  end

  if M.first_request_scheduled(ctx) then
    return
  end

  get_suggestions_cycling(function(context)
    advance(-1, context)
  end, ctx)
end

---@param modifier? (fun(suggestion: copilot_get_completions_data_completion): copilot_get_completions_data_completion)
function M.accept(modifier)
  local ctx = get_ctx()
  logger.trace("suggestion accept", ctx)

  if config.suggestion.trigger_on_accept and not get_current_suggestion(ctx) and M.first_request_scheduled(ctx) then
    return
  end

  local suggestion = get_current_suggestion(ctx)
  if not suggestion or vim.fn.empty(suggestion.text) == 1 then
    return
  end

  if type(modifier) == "function" then
    suggestion = modifier(suggestion)
  end

  local accepted_partial = suggestion.partial_text and suggestion.partial_text ~= ""

  if not accepted_partial then
    cancel_inflight_requests(ctx)
    reset_ctx(ctx)
  end

  with_client(function(client)
    local ok, err = pcall(function()
      api.notify_accepted(
        client,
        { uuid = suggestion.uuid, acceptedLength = util.strutf16len(suggestion.text) },
        function() end
      )
    end)
    if not ok then
      logger.error(string.format("failed to notify_accepted for: %s, Error: %s", suggestion.text, err))
    end
  end)

  local newText

  if accepted_partial then
    newText = suggestion.partial_text
    ctx.accepted_partial = true
    ignore_next_cursor_moved = true
  else
    M.clear_preview()
    newText = suggestion.text
  end

  local range = suggestion.range
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, character = cursor[1] - 1, cursor[2]
  if range["end"].line == line and range["end"].character < character then
    range["end"].character = character
  end

  vim.schedule_wrap(function()
    -- Create an undo breakpoint
    vim.cmd("let &undolevels=&undolevels")
    -- Hack for 'autoindent', makes the indent persist. Check `:help 'autoindent'`.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space><Left><Del>", true, false, true), "n", false)
    local bufnr = vim.api.nvim_get_current_buf()

    -- only utf encodings are supported
    local encoding = vim.api.nvim_get_option_value("fileencoding", { buf = bufnr })
    if not encoding or encoding == "" or encoding ~= "utf-8" or encoding ~= "utf-16" or encoding ~= "utf-32" then
      encoding = vim.api.nvim_get_option_value("encoding", { scope = "global" })

      if not encoding or encoding == "" or encoding ~= "utf-8" or encoding ~= "utf-16" or encoding ~= "utf-32" then
        encoding = "utf-8"
      end
    end

    local lines = vim.split(newText, "\n", { plain = true })
    local lines_count = #lines
    local last_col = #lines[lines_count]

    -- apply_text_edits will remove the last \n if the last line is empty,
    -- so we trick it by adding an extra one
    if last_col == 0 then
      newText = newText .. "\n"
    end

    vim.lsp.util.apply_text_edits({ { range = range, newText = newText } }, bufnr, encoding)

    -- Position cursor at the end of the last inserted line
    local new_cursor_line = range["start"].line + #lines
    vim.api.nvim_win_set_cursor(0, { new_cursor_line, last_col })

    if accepted_partial then
      suggestion.partial_text = nil

      for _ = 1, lines_count - 1 do
        suggestion.text = suggestion.text:sub(suggestion.text:find("\n") + 1)
        suggestion.displayText = suggestion.displayText:sub(suggestion.displayText:find("\n") + 1)
      end

      update_ctx_suggestion_position(ctx.choice, new_cursor_line - 1, last_col, bufnr)
      M.update_preview(ctx)
    end
  end)()
end

function M.accept_word()
  M.accept(function(suggestion)
    local range, text = suggestion.range, suggestion.text

    local cursor = vim.api.nvim_win_get_cursor(0)
    local _, character = cursor[1], cursor[2]

    local _, char_idx = string.find(text, "%s*%p*[^%s%p]*%s*", character + 1)
    if char_idx then
      suggestion.partial_text = string.sub(text, 1, char_idx)
      range["end"].character = char_idx
    end

    range["end"].line = range["start"].line
    return suggestion
  end)
end

function M.accept_line()
  M.accept(function(suggestion)
    local range, text = suggestion.range, suggestion.text

    local cursor = vim.api.nvim_win_get_cursor(0)
    local _, character = cursor[1], cursor[2]

    local next_char = string.sub(text, character + 1, character + 1)
    local _, char_idx = string.find(text, next_char == "\n" and "\n%s*[^\n]*\n%s*" or "\n%s*", character)
    if char_idx then
      suggestion.partial_text = string.sub(text, 1, char_idx)
      range["end"].character = char_idx
    end

    range["end"].line = range["start"].line
    return suggestion
  end)
end

function M.dismiss()
  local ctx = get_ctx()
  reject()
  clear(ctx)
  M.update_preview(ctx)
end

function M.is_visible()
  return not not vim.api.nvim_buf_get_extmark_by_id(0, copilot.ns_id, copilot.extmark_id, { details = false })[1]
end

-- toggles auto trigger for the current buffer
function M.toggle_auto_trigger()
  vim.b.copilot_suggestion_auto_trigger = not should_auto_trigger()
end

local function on_insert_leave()
  clear()
end

local function on_buf_leave()
  if vim.fn.mode():match("^[iR]") then
    on_insert_leave()
  end
end

local function on_insert_enter(args)
  logger.trace("insert enter")
  local bufnr = (args and args.buf) or nil
  request_suggestion_when_auto_trigger(bufnr)
end

local function on_buf_enter(args)
  if vim.fn.mode():match("^[iR]") then
    logger.trace("buf enter")
    local bufnr = (args and args.buf) or nil
    request_suggestion_when_auto_trigger(bufnr)
  end
end

local function on_cursor_moved_i(args)
  if ignore_next_cursor_moved then
    ignore_next_cursor_moved = false
    return
  end

  local ctx = get_ctx()
  if copilot._copilot_timer or ctx.params or should_auto_trigger() then
    logger.trace("cursor moved insert")
    local bufnr = (args and args.buf) or nil
    request_suggestion(bufnr)
  end
end

local function on_text_changed_p(args)
  local ctx = get_ctx()

  if not copilot.hide_during_completion and (copilot._copilot_timer or ctx.params or should_auto_trigger()) then
    logger.trace("text changed pum")
    local bufnr = (args and args.buf) or nil
    request_suggestion(bufnr)
  end
end

local function on_complete_changed()
  clear()
end

---@param info { buf: integer }
local function on_buf_unload(info)
  reject(info.buf)
  copilot.context[info.buf] = nil
end

local function on_vim_leave_pre()
  reject()
end

local function create_autocmds()
  vim.api.nvim_create_augroup(copilot.augroup, { clear = true })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = copilot.augroup,
    callback = on_insert_leave,
    desc = "[copilot] (suggestion) insert leave",
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = copilot.augroup,
    callback = on_buf_leave,
    desc = "[copilot] (suggestion) buf leave",
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = copilot.augroup,
    callback = function(args)
      on_insert_enter(args)
    end,
    desc = "[copilot] (suggestion) insert enter",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = copilot.augroup,
    callback = function(args)
      on_buf_enter(args)
    end,
    desc = "[copilot] (suggestion) buf enter",
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = copilot.augroup,
    callback = function(args)
      on_cursor_moved_i(args)
    end,
    desc = "[copilot] (suggestion) cursor moved insert",
  })

  vim.api.nvim_create_autocmd("TextChangedP", {
    group = copilot.augroup,
    callback = function(args)
      on_text_changed_p(args)
    end,
    desc = "[copilot] (suggestion) text changed pum",
  })

  vim.api.nvim_create_autocmd("CompleteChanged", {
    group = copilot.augroup,
    callback = on_complete_changed,
    desc = "[copilot] (suggestion) complete changed",
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = copilot.augroup,
    callback = function(args)
      on_buf_unload(args)
    end,
    desc = "[copilot] (suggestion) buf unload",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = copilot.augroup,
    callback = on_vim_leave_pre,
    desc = "[copilot] (suggestion) vim leave pre",
  })
end

function M.setup()
  local opts = config.suggestion
  if not opts.enabled then
    return
  end

  if copilot.setup_done then
    return
  end

  copilot.auto_trigger = opts.auto_trigger
  copilot.hide_during_completion = opts.hide_during_completion

  create_autocmds()

  copilot.debounce = opts.debounce
  copilot.setup_done = true
end

function M.teardown()
  local opts = config.suggestion
  if not opts.enabled then
    return
  end

  if not copilot.setup_done then
    return
  end

  vim.api.nvim_clear_autocmds({ group = copilot.augroup })
  copilot.setup_done = false
end

return M
