M = {
  extmark_id = 1,
}
local logger = require("copilot.logger")
local context = require("copilot.suggestion.context")
local suggestion_util = require("copilot.suggestion.utils")
local config = require("copilot.config")
local api = require("copilot.api")
local hl_group = require("copilot.highlight").group
local utils = require("copilot.suggestion.utils")

---@return boolean
function M.is_visible()
  return not not vim.api.nvim_buf_get_extmark_by_id(0, utils.ns_id, M.extmark_id, { details = false })[1]
end

function M.clear_preview()
  logger.trace("suggestion clear preview")
  vim.api.nvim_buf_del_extmark(0, utils.ns_id, M.extmark_id)
end

---@param ctx? copilot_suggestion_context
function M.update_preview(ctx)
  ctx = ctx or context.get_ctx()
  logger.trace("suggestion update preview", ctx)

  local suggestion = context.get_current_suggestion(ctx)
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
    context.set_ctx_suggestion_text(ctx.choice, suggest_text)
  end

  local extmark = {
    id = M.extmark_id,
    virt_text = { { suggestion_line1, hl_group.CopilotSuggestion } },
    virt_text_pos = "inline",
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

  extmark.hl_mode = "replace"
  vim.api.nvim_buf_set_extmark(0, utils.ns_id, vim.fn.line(".") - 1, cursor_col - 1, extmark)

  if config.suggestion.suggestion_notification then
    vim.schedule(function()
      config.suggestion.suggestion_notification(extmark.virt_text, extmark.virt_lines or {})
    end)
  end

  if not ctx.shown_choices[suggestion.uuid] then
    ctx.shown_choices[suggestion.uuid] = true
    utils.with_client(function(client)
      api.notify_shown(client, { uuid = suggestion.uuid }, function() end)
    end)
  end
end

return M
