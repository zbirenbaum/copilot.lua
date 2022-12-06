local api = require("copilot.api")
local hl_group = require("copilot.highlight").group
local util = require("copilot.util")

local mod = {}

local copilot = {
  setup_done = false,

  augroup = "copilot.suggestion",
  ns_id = vim.api.nvim_create_namespace("copilot.suggestion"),
  extmark_id = 1,

  uuid = nil,
  _copilot_timer = nil,
  _copilot = {
    first = nil,
    cycling = nil,
    cycling_callbacks = nil,
    params = nil,
    suggestions = nil,
    choice = nil,
  },

  auto_trigger = false,
  debounce = 75,
}

local function get_client()
  if not copilot.client then
    copilot.client = util.get_copilot_client()
  end
  return copilot.client
end

local function with_client(fn)
  local client = get_client()
  if client then
    fn(client)
  end
end

local function is_enabled()
  local client = get_client()
  return client and vim.lsp.buf_is_attached(0, client.id) or false
end

local function should_auto_trigger()
  if vim.b.copilot_suggestion_auto_trigger == nil then
    return copilot.auto_trigger
  end
  return vim.b.copilot_suggestion_auto_trigger
end

local function reset_state()
  copilot._copilot = {
    first = nil,
    cycling = nil,
    cycling_callbacks = nil,
    params = nil,
    suggestions = nil,
    choice = nil,
  }
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
    vim.keymap.set("i", keymap.dismiss, mod.dismiss, {
      desc = "[copilot] dismiss suggestion",
      silent = true,
    })
  end
end

local function stop_timer()
  if copilot._copilot_timer then
    vim.fn.timer_stop(copilot._copilot_timer)
    copilot._copilot_timer = nil
  end
end

local function reject_current()
  if copilot.uuid then
    with_client(function(client)
      api.notify_rejected(client, { uuids = { copilot.uuid } }, function() end)
    end)
    copilot.uuid = nil
  end
end

local function cancel_inflight_requests()
  with_client(function(client)
    if copilot._copilot.first then
      client.cancel_request(copilot._copilot.first)
      copilot._copilot.first = nil
    end
    if copilot._copilot.cycling then
      client.cancel_request(copilot._copilot.cycling)
      copilot._copilot.cycling = nil
    end
  end)
end

local function clear_preview()
  vim.api.nvim_buf_del_extmark(0, copilot.ns_id, copilot.extmark_id)
end

local function get_current_suggestion()
  local ok, choice = pcall(function()
    if
      not vim.fn.mode():match("^[iR]")
      or vim.fn.pumvisible() == 1
      or vim.b.copilot_suggestion_hidden
      or not copilot._copilot.suggestions
      or #copilot._copilot.suggestions == 0
    then
      return nil
    end

    local choice = copilot._copilot.suggestions[copilot._copilot.choice]
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

local function update_preview()
  local suggestion = get_current_suggestion()
  local displayLines = suggestion and vim.split(suggestion.displayText, "\n", { plain = true }) or {}

  clear_preview()

  if not suggestion or #displayLines == 0 then
    return
  end

  ---@todo support popup preview

  local annot = ""
  if copilot._copilot.cycling_callbacks then
    annot = "(1/…)"
  elseif copilot._copilot.cycling then
    annot = "(" .. copilot._copilot.choice .. "/" .. #copilot._copilot.suggestions .. ")"
  end

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

  vim.api.nvim_buf_set_extmark(0, copilot.ns_id, vim.fn.line(".") - 1, vim.fn.col(".") - 1, extmark)

  if suggestion.uuid ~= copilot.uuid then
    copilot.uuid = suggestion.uuid
    with_client(function(client)
      api.notify_shown(client, { uuid = suggestion.uuid }, function() end)
    end)
  end
end

local function clear()
  stop_timer()
  reject_current()
  cancel_inflight_requests()
  update_preview()
  reset_state()
end

---@param callback fun(err: any|nil, data: copilot_get_completions_data): nil
local function complete(callback)
  stop_timer()

  local params = util.get_doc_params()

  if not vim.deep_equal(copilot._copilot.params, params) then
    with_client(function(client)
      local _, id = api.get_completions(client, params, callback)
      copilot._copilot = { params = params, first = id }
    end)
  end
end

---@param data copilot_get_completions_data
local function handle_trigger_request(err, data)
  if err then
    print(err)
  end
  copilot._copilot.suggestions = data and data.completions or {}
  copilot._copilot.choice = 1
  update_preview()
end

local function trigger(bufnr, timer)
  local _timer = copilot._copilot_timer
  copilot._copilot_timer = nil

  if bufnr ~= vim.api.nvim_get_current_buf() or timer ~= _timer or vim.fn.mode() ~= "i" then
    return
  end

  complete(handle_trigger_request)
end

local function get_suggestions_cycling_callback(state, err, data)
  local callbacks = state.cycling_callbacks
  state.cycling_callbacks = nil

  if err then
    print(err)
  end

  local seen = {}

  for _, suggestion in ipairs(state.suggestions or {}) do
    seen[suggestion.text] = true
  end

  for _, suggestion in ipairs(data.completions or {}) do
    if not seen[suggestion.text] then
      table.insert(state.suggestions, suggestion)
      seen[suggestion.text] = true
    end
  end

  for _, callback in ipairs(callbacks) do
    callback(state)
  end
end

local function get_suggestions_cycling(callback)
  if copilot._copilot.cycling_callbacks then
    table.insert(copilot._copilot.cycling_callbacks, callback)
    return
  end

  if copilot._copilot.cycling then
    callback(copilot._copilot)
    return
  end

  if copilot._copilot.suggestions then
    copilot._copilot.cycling_callbacks = { callback }
    with_client(function(client)
      local _, id = api.get_completions_cycling(client, copilot._copilot.params, function(err, data)
        get_suggestions_cycling_callback(copilot._copilot, err, data)
      end)
      copilot._copilot.cycling = id
      update_preview()
    end)
  end
end

local function advance(count, state)
  if state ~= copilot._copilot then
    return
  end

  state.choice = (state.choice + count) % #state.suggestions
  if state.choice < 1 then
    state.choice = #state.suggestions
  end

  update_preview()
end

local function schedule()
  clear()

  if not is_enabled() then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  copilot._copilot_timer = vim.fn.timer_start(copilot.debounce, function(timer)
    trigger(bufnr, timer)
  end)
end

function mod.next()
  if not copilot._copilot.params and not should_auto_trigger() then
    schedule()
    return
  end

  get_suggestions_cycling(function(state)
    advance(1, state)
  end)
end

function mod.prev()
  if not copilot._copilot.params and not should_auto_trigger() then
    schedule()
    return
  end

  get_suggestions_cycling(function(state)
    advance(-1, state)
  end)
end

---@param partial? 'word'|'line'
local function accept_suggestion(partial)
  local suggestion = get_current_suggestion()
  if not suggestion or vim.fn.empty(suggestion.text) == 1 then
    return
  end

  reset_state()
  with_client(function(client)
    if partial then
      -- do not notify_accepted for partial accept.
      -- revisit if upstream copilot.vim adds this feature.
      return
    end

    api.notify_accepted(client, { uuid = suggestion.uuid }, function() end)
  end)
  copilot.uuid = nil
  clear_preview()

  local range, newText = suggestion.range, suggestion.text

  if partial then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local _, character = cursor[1], cursor[2]

    if partial == "word" then
      local _, char_idx = string.find(newText, "%s*%p*[^%s%p]*%s*", character + 1)
      if not char_idx then
        return
      end

      newText = string.sub(newText, 1, char_idx)

      range["end"].line = range["start"].line
      range["end"].character = char_idx
    elseif partial == "line" then
      local next_char = string.sub(newText, character + 1, character + 1)
      local _, char_idx = string.find(newText, next_char == "\n" and "\n%s*[^\n]*\n%s*" or "\n%s*", character)
      if char_idx then
        newText = string.sub(newText, 1, char_idx)
      end
    end
  end

  -- Hack for 'autoindent', makes the indent persist. Check `:help 'autoindent'`.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space><Left><Del>", true, false, true), "n", false)
  vim.lsp.util.apply_text_edits({ { range = range, newText = newText } }, 0, "utf-16")
  -- Put cursor at the end of current line.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<End>", true, false, true), "n", false)
end

function mod.accept()
  accept_suggestion()
end

function mod.accept_word()
  accept_suggestion("word")
end

function mod.accept_line()
  accept_suggestion("line")
end

function mod.dismiss()
  clear()
  update_preview()
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
  if copilot._copilot_timer or copilot._copilot.params or should_auto_trigger() then
    schedule()
  end
end

local function on_complete_changed()
  clear()
end

function mod.setup(config)
  if copilot.setup_done then
    return
  end

  set_keymap(config.keymap or {})

  copilot.auto_trigger = config.auto_trigger

  vim.api.nvim_create_autocmd("InsertLeave", {
    callback = on_insert_leave,
    desc = "[copilot] (suggestion) insert leave",
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    callback = on_buf_leave,
    desc = "[copilot] (suggestion) buf leave",
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = on_insert_enter,
    desc = "[copilot] (suggestion) insert enter",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    callback = on_buf_enter,
    desc = "[copilot] (suggestion) buf enter",
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    callback = on_cursor_moved_i,
    desc = "[copilot] (suggestion) cursor moved insert",
  })

  vim.api.nvim_create_autocmd("CompleteChanged", {
    callback = on_complete_changed,
    desc = "[copilot] (suggestion) complete changed",
  })

  copilot.debounce = config.debounce

  copilot.setup_done = true
end

return mod
