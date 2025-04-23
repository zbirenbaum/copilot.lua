local M = {
  augroup = "copilot.suggestion",
}

local logger = require("copilot.logger")
local context = require("copilot.suggestion.context")
local ignore_next_cursor_moved = false
local timer = require("copilot.suggestion.timer")

local function on_insert_leave()
  context.clear()
end

local function on_buf_leave()
  if vim.fn.mode():match("^[iR]") then
    on_insert_leave()
  end
end

local function on_insert_enter()
  if context.should_auto_trigger() then
    logger.trace("suggestion on insert enter")
    context.schedule()
  end
end

local function on_buf_enter()
  if vim.fn.mode():match("^[iR]") then
    on_insert_enter()
  end
end

local function on_cursor_moved_i()
  if ignore_next_cursor_moved then
    ignore_next_cursor_moved = false
    return
  end

  local ctx = context.get_ctx()
  if timer.copilot_timer or ctx.params or context.should_auto_trigger() then
    logger.trace("suggestion on cursor moved insert")
    context.schedule(ctx)
  end
end

local function on_text_changed_p()
  local ctx = context.get_ctx()
  if not context.hide_during_completion and (timer.copilot_timer or ctx.params or context.should_auto_trigger()) then
    logger.trace("suggestion on text changed pum")
    context.schedule(ctx)
  end
end

local function on_complete_changed()
  context.clear()
end

---@param info { buf: integer }
local function on_buf_unload(info)
  context.reject(info.buf)
  context.context[info.buf] = nil
end

local function on_vim_leave_pre()
  context.reject()
end

function M.ignore_next_cursor_moved()
  ignore_next_cursor_moved = true
end

function M.create_autocmds()
  vim.api.nvim_create_augroup(M.augroup, { clear = true })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = M.augroup,
    callback = on_insert_leave,
    desc = "[copilot] (suggestion) insert leave",
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = M.augroup,
    callback = on_buf_leave,
    desc = "[copilot] (suggestion) buf leave",
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = M.augroup,
    callback = on_insert_enter,
    desc = "[copilot] (suggestion) insert enter",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = M.augroup,
    callback = on_buf_enter,
    desc = "[copilot] (suggestion) buf enter",
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = M.augroup,
    callback = on_cursor_moved_i,
    desc = "[copilot] (suggestion) cursor moved insert",
  })

  vim.api.nvim_create_autocmd("TextChangedP", {
    group = M.augroup,
    callback = on_text_changed_p,
    desc = "[copilot] (suggestion) text changed pum",
  })

  vim.api.nvim_create_autocmd("CompleteChanged", {
    group = M.augroup,
    callback = on_complete_changed,
    desc = "[copilot] (suggestion) complete changed",
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = M.augroup,
    callback = on_buf_unload,
    desc = "[copilot] (suggestion) buf unload",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = M.augroup,
    callback = on_vim_leave_pre,
    desc = "[copilot] (suggestion) vim leave pre",
  })
end

return M
