local api = require("copilot.api")
local config = require("copilot.config")
local util = require("copilot.util")
local logger = require("copilot.logger")
local events = require("copilot.suggestion.events")
local context = require("copilot.suggestion.context")
local utils = require("copilot.suggestion.utils")
local preview = require("copilot.suggestion.preview")

local M = {}

---@alias copilot_suggestion_context { first?: integer, cycling?: integer, cycling_callbacks?: (fun(ctx: copilot_suggestion_context):nil)[], params?: table, suggestions?: copilot_get_completions_data_completion[], choice?: integer, shown_choices?: table<string, true>, accepted_partial?: boolean }

local copilot = {
  setup_done = false,
  debounce = 75,
}

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
    utils.with_client(function(client)
      local _, id = api.get_completions_cycling(client, ctx.params, function(err, data)
        get_suggestions_cycling_callback(ctx, err, data)
      end)
      ctx.cycling = id --[[@as integer]]
      preview.update_preview(ctx)
    end)
  end
end

local function advance(count, ctx)
  if ctx ~= context.get_ctx() then
    return
  end

  ctx.choice = (ctx.choice + count) % #ctx.suggestions
  if ctx.choice < 1 then
    ctx.choice = #ctx.suggestions
  end

  preview.update_preview(ctx)
end

function M.next()
  local ctx = context.get_ctx()
  logger.trace("suggestion next", ctx)

  if ctx.accepted_partial then
    context.reset_ctx(ctx)
  end

  -- no suggestion request yet
  if not ctx.first then
    logger.trace("suggestion next, no first request")
    context.schedule(ctx)
    return
  end

  get_suggestions_cycling(function(curr_ctx)
    advance(1, curr_ctx)
  end, ctx)
end

function M.prev()
  local ctx = context.get_ctx()
  logger.trace("suggestion prev", ctx)

  if ctx.accepted_partial then
    context.reset_ctx(ctx)
  end

  -- no suggestion request yet
  if not ctx.first then
    logger.trace("suggestion prev, no first request", ctx)
    context.schedule(ctx)
    return
  end

  get_suggestions_cycling(function(curr_context)
    advance(-1, curr_context)
  end, ctx)
end

---@param modifier? (fun(suggestion: copilot_get_completions_data_completion): copilot_get_completions_data_completion)
function M.accept(modifier)
  local ctx = context.get_ctx()
  logger.trace("suggestion accept", ctx)

  -- no suggestion request yet
  if (not ctx.first) and config.suggestion.trigger_on_accept then
    logger.trace("suggestion accept, not first request", ctx)
    context.schedule(ctx)
    return
  end

  local suggestion = context.get_current_suggestion(ctx)
  if not suggestion or vim.fn.empty(suggestion.text) == 1 then
    return
  end

  if type(modifier) == "function" then
    suggestion = modifier(suggestion)
  end

  local accepted_partial = suggestion.partial_text and suggestion.partial_text ~= ""

  if not accepted_partial then
    context.cancel_inflight_requests(ctx)
    context.reset_ctx(ctx)
  end

  utils.with_client(function(client)
    local ok, _ = pcall(function()
      api.notify_accepted(
        client,
        { uuid = suggestion.uuid, acceptedLength = util.strutf16len(suggestion.text) },
        function() end
      )
    end)
    if not ok then
      logger.error(string.format("failed to notify_accepted for: %s, Error: %s", suggestion.text))
    end
  end)

  local newText

  if accepted_partial then
    newText = suggestion.partial_text
    ctx.accepted_partial = true
    events.ignore_next_cursor_moved()
  else
    preview.clear_preview()
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

      context.update_ctx_suggestion_position(ctx.choice, new_cursor_line - 1, last_col, bufnr)
      preview.update_preview(ctx)
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
  local ctx = context.get_ctx()
  context.reject()
  context.clear(ctx)
  preview.update_preview(ctx)
end

-- toggles auto trigger for the current buffer
function M.toggle_auto_trigger()
  vim.b.copilot_suggestion_auto_trigger = not context.should_auto_trigger()
end

function M.setup()
  local opts = config.suggestion
  if not opts.enabled then
    return
  end

  if copilot.setup_done then
    return
  end

  require("copilot.suggestion.keymaps").set_keymap(opts.keymap or {})
  context.auto_trigger = opts.auto_trigger
  context.hide_during_completion = opts.hide_during_completion
  events.create_autocmds()
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

  require("copilot.suggestion.keymaps").unset_keymap(opts.keymap or {})
  vim.api.nvim_clear_autocmds({ group = events.augroup })
  copilot.setup_done = false
end

-- External API
function M.is_visible()
  return preview.is_visible()
end

return M
