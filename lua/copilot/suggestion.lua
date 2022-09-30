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

---@return string text
---@return integer outdent
---@return integer delete
---@return string uuid
local function suggestion_text_with_adjustments()
  local ok, text, outdent, delete, uuid = pcall(function()
    if
      not vim.fn.mode():match("^[iR]")
      or vim.fn.pumvisible() == 1
      or vim.b.copilot_suggestion_hidden
      or not copilot._copilot.suggestions
      or #copilot._copilot.suggestions == 0
    then
      return "", 0, 0, ""
    end

    local choice = copilot._copilot.suggestions[copilot._copilot.choice]
    if not choice or not choice.range or choice.range.start.line ~= vim.fn.line(".") - 1 then
      return "", 0, 0, ""
    end

    if choice.range.start.character ~= 0 then
      -- unexpected range
      return "", 0, 0, ""
    end

    local line = vim.fn.getline(".")
    local offset = vim.fn.col(".") - 1

    local typed = vim.fn.strpart(line, 0, offset)
    local delete = vim.fn.strpart(line, offset)

    local uuid = choice.uuid or ""

    if typed:match("^%s*$") then
      local leading = vim.fn.matchstr(choice.text, "^s+")
      local unindented = vim.fn.strpart(choice.text, #leading)
      if vim.fn.strpart(typed, 0, #leading) == leading or unindented ~= delete then
        return unindented, #typed - #leading, vim.fn.strchars(delete), uuid
      end
    else
      return vim.fn.strpart(choice.text, offset), 0, vim.fn.strchars(delete), uuid
    end
  end)

  if ok then
    return text, outdent, delete, uuid
  end

  return "", 0, 0, ""
end

local function clear_preview()
  vim.api.nvim_buf_del_extmark(0, copilot.ns_id, copilot.extmark_id)
end

local function update_preview()
  local text, _, delete, uuid = suggestion_text_with_adjustments()
  text = vim.split(text, "\n", { plain = true, trimempty = true })

  clear_preview()

  if #text == 0 then
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
    virt_text = { { text[1] .. string.rep(" ", delete - #text[1]), hl_group.CopilotSuggestion } },
  }

  if #text > 1 then
    extmark.virt_lines = {}
    for i = 2, #text do
      extmark.virt_lines[i - 1] = { { text[i], hl_group.CopilotSuggestion } }
    end
    if #annot > 0 then
      extmark.virt_lines[#text] = { { " " }, { annot, hl_group.CopilotAnnotation } }
    end
  elseif #annot > 0 then
    extmark.virt_text[2] = { " " }
    extmark.virt_text[3] = { annot, hl_group.CopilotAnnotation }
  end

  extmark.hl_mode = "combine"

  vim.api.nvim_buf_set_extmark(0, copilot.ns_id, vim.fn.line(".") - 1, vim.fn.col(".") - 1, extmark)

  if uuid ~= copilot.uuid then
    copilot.uuid = uuid
    with_client(function(client)
      api.notify_shown(client, { uuid = uuid }, function() end)
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

local function get_displayed_suggestion()
  local text, outdent, delete, uuid = suggestion_text_with_adjustments()
  return {
    uuid = uuid,
    text = text,
    outdent_size = outdent,
    delete_size = delete,
  }
end

function mod.accept()
  local s = get_displayed_suggestion()
  if vim.fn.empty(s.text) == 0 then
    reset_state()
    with_client(function(client)
      api.notify_accepted(client, { uuid = s.uuid }, function() end)
    end)
    copilot.uuid = nil
    clear_preview()

    local keys = vim.api.nvim_replace_termcodes(
      string.rep("<Left><Del>", s.outdent_size) .. string.rep("<Del>", s.delete_size),
      true,
      false,
      true
    ) or ""
    vim.api.nvim_feedkeys(keys .. s.text, "n", false)
  end
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
