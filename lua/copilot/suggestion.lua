local api = require("copilot.api")
local c = require("copilot.client")
local config = require("copilot.config")
local hl_group = require("copilot.highlight").group
local util = require("copilot.util")

local _, has_nvim_0_10_x = pcall(function()
  return vim.version().minor >= 10
end)

local mod = {}

---@alias copilot_suggestion_context { first?: integer, cycling?: integer, cycling_callbacks?: (fun(ctx: copilot_suggestion_context):nil)[], params?: table, suggestions?: copilot_get_completions_data_completion[], choice?: integer, shown_choices?: table<string, true> }

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

local function with_client(fn)
  local client = c.get()
  if client then
    fn(client)
  end
end

local function is_enabled()
  return c.buf_is_attached(0)
end

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
  end
  return ctx
end

---@param ctx copilot_suggestion_context
local function reset_ctx(ctx)
  ctx.first = nil
  ctx.cycling = nil
  ctx.cycling_callbacks = nil
  ctx.params = nil
  ctx.suggestions = nil
  ctx.choice = nil
  ctx.shown_choices = nil
end

local function set_keymap(keymap)
  if keymap.accept then
    vim.keymap.set("i", keymap.accept, mod.accept, {
      desc = "[copilot] accept suggestion",
      silent = true,
    })
  end

  if keymap.accept_word then
    vim.keymap.set("i", keymap.accept_word, mod.accept_word, {
      desc = "[copilot] accept suggestion (word)",
      silent = true,
    })
  end

  if keymap.accept_line then
    vim.keymap.set("i", keymap.accept_line, mod.accept_line, {
      desc = "[copilot] accept suggestion (line)",
      silent = true,
    })
  end

  if keymap.next then
    vim.keymap.set("i", keymap.next, mod.next, {
      desc = "[copilot] next suggestion",
      silent = true,
    })
  end

  if keymap.prev then
    vim.keymap.set("i", keymap.prev, mod.prev, {
      desc = "[copilot] prev suggestion",
      silent = true,
    })
  end

  if keymap.dismiss then
    vim.keymap.set("i", keymap.dismiss, function()
      if mod.is_visible() then
        mod.dismiss()
        return "<Ignore>"
      else
        return keymap.dismiss
      end
    end, {
      desc = "[copilot] dismiss suggestion",
      expr = true,
      silent = true,
    })
  end
end

local function unset_keymap(keymap)
  if keymap.accept then
    vim.keymap.del("i", keymap.accept)
  end

  if keymap.accept_word then
    vim.keymap.del("i", keymap.accept_word)
  end

  if keymap.accept_line then
    vim.keymap.del("i", keymap.accept_line)
  end

  if keymap.next then
    vim.keymap.del("i", keymap.next)
  end

  if keymap.prev then
    vim.keymap.del("i", keymap.prev)
  end

  if keymap.dismiss then
    vim.keymap.del("i", keymap.dismiss)
  end
end

local function stop_timer()
  if copilot._copilot_timer then
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
  ctx = ctx or get_ctx()

  with_client(function(client)
    if ctx.first then
      client.cancel_request(ctx.first)
      ctx.first = nil
    end
    if ctx.cycling then
      client.cancel_request(ctx.cycling)
      ctx.cycling = nil
    end
  end)
end

local function clear_preview()
  vim.api.nvim_buf_del_extmark(0, copilot.ns_id, copilot.extmark_id)
end

---@param ctx? copilot_suggestion_context
---@return copilot_get_completions_data_completion|nil
local function get_current_suggestion(ctx)
  ctx = ctx or get_ctx()

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

    if choice.range.start.character ~= 0 then
      -- unexpected range
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
local function update_preview(ctx)
  ctx = ctx or get_ctx()

  local suggestion = get_current_suggestion(ctx)
  local displayLines = suggestion and vim.split(suggestion.displayText, "\n", { plain = true }) or {}

  clear_preview()

  if not suggestion or #displayLines == 0 then
    return
  end

  ---@todo support popup preview

  local annot = ""
  if ctx.cycling_callbacks then
    annot = "(1/…)"
  elseif ctx.cycling then
    annot = "(" .. ctx.choice .. "/" .. #ctx.suggestions .. ")"
  end

  local cursor_col = vim.fn.col(".")

  displayLines[1] =
      string.sub(string.sub(suggestion.text, 1, (string.find(suggestion.text, "\n", 1, true) or 0) - 1), cursor_col)

  local extmark = {
    id = copilot.extmark_id,
    virt_text_win_col = vim.fn.virtcol(".") - 1,
    virt_text = { { displayLines[1], hl_group.CopilotSuggestion } },
  }

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

  extmark.hl_mode = "combine"

  vim.api.nvim_buf_set_extmark(0, copilot.ns_id, vim.fn.line(".") - 1, cursor_col - 1, extmark)

  if not ctx.shown_choices[suggestion.uuid] then
    ctx.shown_choices[suggestion.uuid] = true
    with_client(function(client)
      api.notify_shown(client, { uuid = suggestion.uuid }, function() end)
    end)
  end
end

---@param ctx? copilot_suggestion_context
local function clear(ctx)
  ctx = ctx or get_ctx()
  stop_timer()
  cancel_inflight_requests(ctx)
  update_preview(ctx)
  reset_ctx(ctx)
end

---@param callback fun(err: any|nil, data: copilot_get_completions_data): nil
local function complete(callback)
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
    print(err)
  end
  local ctx = get_ctx()
  ctx.suggestions = data and data.completions or {}
  ctx.choice = 1
  ctx.shown_choices = {}
  update_preview()
end

local function trigger(bufnr, timer)
  local _timer = copilot._copilot_timer
  copilot._copilot_timer = nil

  if bufnr ~= vim.api.nvim_get_current_buf() or (_timer ~= nil and timer ~= _timer) or vim.fn.mode() ~= "i" then
    return
  end

  complete(handle_trigger_request)
end

---@param ctx copilot_suggestion_context
local function get_suggestions_cycling_callback(ctx, err, data)
  local callbacks = ctx.cycling_callbacks or {}
  ctx.cycling_callbacks = nil

  if err then
    print(err)
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
      update_preview(ctx)
    end)
  end
end

local function advance(count, ctx)
  if ctx ~= get_ctx() then
    return
  end

  ctx.choice = (ctx.choice + count) % #ctx.suggestions
  if ctx.choice < 1 then
    ctx.choice = #ctx.suggestions
  end

  update_preview(ctx)
end

local function schedule(ctx)
  if not is_enabled() or not c.initialized then
    clear()
    return
  end

  update_preview(ctx)
  local bufnr = vim.api.nvim_get_current_buf()
  copilot._copilot_timer = vim.fn.timer_start(copilot.debounce, function(timer)
    trigger(bufnr, timer)
  end)
end

function mod.next()
  local ctx = get_ctx()

  -- no suggestion request yet
  if not ctx.first then
    schedule(ctx)
    return
  end

  get_suggestions_cycling(function(context)
    advance(1, context)
  end, ctx)
end

function mod.prev()
  local ctx = get_ctx()

  -- no suggestion request yet
  if not ctx.first then
    schedule(ctx)
    return
  end

  get_suggestions_cycling(function(context)
    advance(-1, context)
  end, ctx)
end

---@param modifier? (fun(suggestion: copilot_get_completions_data_completion): copilot_get_completions_data_completion)
function mod.accept(modifier)
  local ctx = get_ctx()

  local suggestion = get_current_suggestion(ctx)
  if not suggestion or vim.fn.empty(suggestion.text) == 1 then
    return
  end

  cancel_inflight_requests(ctx)
  reset_ctx(ctx)

  if type(modifier) == "function" then
    suggestion = modifier(suggestion)
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
      vim.notify(
        table.concat({ "[Copilot] failed to notify_accepted for: " .. suggestion.text, "Error: " .. err }, "\n\n"),
        vim.log.levels.ERROR
      )
    end
  end)

  clear_preview()

  local range, newText = suggestion.range, suggestion.text
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, character = cursor[1] - 1, cursor[2]
  if range["end"].line == line and range["end"].character < character then
    range["end"].character = character
  end

  -- Hack for 'autoindent', makes the indent persist. Check `:help 'autoindent'`.
  vim.schedule_wrap(function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space><Left><Del>", true, false, true), "n", false)
      local bufnr = vim.api.nvim_get_current_buf()
    local encoding = vim.api.nvim_get_option_value("fileencoding", { buf = bufnr }) ~= ""
        and vim.api.nvim_get_option_value("fileencoding", { buf = bufnr })
      or vim.api.nvim_get_option_value("encoding", { scope = "global" })
    vim.lsp.util.apply_text_edits({ { range = range, newText = newText } }, bufnr, encoding)
    -- Put cursor at the end of current line.
    local cursor_keys = "<End>"
    if has_nvim_0_10_x then
      cursor_keys = string.rep("<Down>", #vim.split(newText, "\n", { plain = true }) - 1) .. cursor_keys
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cursor_keys, true, false, true), "n", false)
  end)()
end

function mod.accept_word()
  mod.accept(function(suggestion)
    local range, text = suggestion.range, suggestion.text

    local cursor = vim.api.nvim_win_get_cursor(0)
    local _, character = cursor[1], cursor[2]

    local _, char_idx = string.find(text, "%s*%p*[^%s%p]*%s*", character + 1)
    if char_idx then
      suggestion.text = string.sub(text, 1, char_idx)

      range["end"].line = range["start"].line
      range["end"].character = char_idx
    end

    return suggestion
  end)
end

function mod.accept_line()
  mod.accept(function(suggestion)
    local text = suggestion.text

    local cursor = vim.api.nvim_win_get_cursor(0)
    local _, character = cursor[1], cursor[2]

    local next_char = string.sub(text, character + 1, character + 1)
    local _, char_idx = string.find(text, next_char == "\n" and "\n%s*[^\n]*\n%s*" or "\n%s*", character)
    if char_idx then
      suggestion.text = string.sub(text, 1, char_idx)
    end

    return suggestion
  end)
end

function mod.dismiss()
  local ctx = get_ctx()
  reject()
  clear(ctx)
  update_preview(ctx)
end

function mod.is_visible()
  return not not vim.api.nvim_buf_get_extmark_by_id(0, copilot.ns_id, copilot.extmark_id, { details = false })[1]
end

-- toggles auto trigger for the current buffer
function mod.toggle_auto_trigger()
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

local function on_insert_enter()
  if should_auto_trigger() then
    schedule()
  end
end

local function on_buf_enter()
  if vim.fn.mode():match("^[iR]") then
    on_insert_enter()
  end
end

local function on_cursor_moved_i()
  local ctx = get_ctx()
  if copilot._copilot_timer or ctx.params or should_auto_trigger() then
    schedule(ctx)
  end
end

local function on_text_changed_p()
  local ctx = get_ctx()
  if not copilot.hide_during_completion and (copilot._copilot_timer or ctx.params or should_auto_trigger()) then
    schedule(ctx)
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
    callback = on_insert_enter,
    desc = "[copilot] (suggestion) insert enter",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = copilot.augroup,
    callback = on_buf_enter,
    desc = "[copilot] (suggestion) buf enter",
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = copilot.augroup,
    callback = on_cursor_moved_i,
    desc = "[copilot] (suggestion) cursor moved insert",
  })

  vim.api.nvim_create_autocmd("TextChangedP", {
    group = copilot.augroup,
    callback = on_text_changed_p,
    desc = "[copilot] (suggestion) text changed pum",
  })

  vim.api.nvim_create_autocmd("CompleteChanged", {
    group = copilot.augroup,
    callback = on_complete_changed,
    desc = "[copilot] (suggestion) complete changed",
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = copilot.augroup,
    callback = on_buf_unload,
    desc = "[copilot] (suggestion) buf unload",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = copilot.augroup,
    callback = on_vim_leave_pre,
    desc = "[copilot] (suggestion) vim leave pre",
  })
end

function mod.setup()
  local opts = config.get("suggestion") --[[@as copilot_config_suggestion]]
  if not opts.enabled then
    return
  end

  if copilot.setup_done then
    return
  end

  set_keymap(opts.keymap or {})

  copilot.auto_trigger = opts.auto_trigger
  copilot.hide_during_completion = opts.hide_during_completion

  create_autocmds()

  copilot.debounce = opts.debounce

  copilot.setup_done = true
end

function mod.teardown()
  local opts = config.get("suggestion") --[[@as copilot_config_suggestion]]
  if not opts.enabled then
    return
  end

  if not copilot.setup_done then
    return
  end

  unset_keymap(opts.keymap or {})

  vim.api.nvim_clear_autocmds({ group = copilot.augroup })

  copilot.setup_done = false
end

return mod
