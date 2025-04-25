local M = {}

---@param bufnr integer
---@param ns_id integer
local function _dismiss_suggestion(bufnr, ns_id)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
end

---@param bufnr? integer
---@param ns_id integer
function M.clear_suggestion(bufnr, ns_id)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
  if vim.b[bufnr].nes_jump then
    vim.b[bufnr].nes_jump = false
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  ---@type copilotlsp.InlineEdit
  local state = vim.b[bufnr].nes_state
  if not state then
    return
  end

  _dismiss_suggestion(bufnr, ns_id)
  vim.b[bufnr].nes_state = nil
end

local function trim_end(s)
  return s:gsub("%s+$", "")
end

---@private
---@param suggestion copilotlsp.InlineEdit
---@return nes.LineCalculationResult
function M._calculate_lines(suggestion)
  local deleted_lines_count = suggestion.range["end"].line - suggestion.range.start.line
  local added_lines = vim.split(trim_end(suggestion.newText), "\n")
  local added_lines_count = suggestion.newText == "" and 0 or #added_lines
  local same_line = 0

  if deleted_lines_count == 0 and added_lines_count == 1 then
    ---changing within line
    deleted_lines_count = 1
    same_line = 1
  end

  -- if
  --     suggestion.range.start.line == suggestion.range["end"].line
  --     and suggestion.range.start.character == suggestion.range["end"].character
  -- then
  --     --add only
  --     TODO: Do we need to position specifically for add only?
  --     UI tests seem to say no
  -- end

  -- Calculate positions for delete highlight extmark
  ---@type nes.DeleteExtmark
  local delete_extmark = {
    row = suggestion.range.start.line,
    end_row = (
      suggestion.range["end"].character ~= 0 and suggestion.range["end"].line + 1 or suggestion.range["end"].line
    ),
  }

  -- Calculate positions for virtual lines extmark
  ---@type nes.VirtLinesExtmark
  local virt_lines_extmark = {
    row = (suggestion.range["end"].character ~= 0 and suggestion.range["end"].line or suggestion.range["end"].line - 1),
    virt_lines_count = added_lines_count,
  }

  return {
    deleted_lines_count = deleted_lines_count,
    added_lines = added_lines,
    added_lines_count = added_lines_count,
    same_line = same_line,
    delete_extmark = delete_extmark,
    virt_lines_extmark = virt_lines_extmark,
  }
end

---@private
---@param edits copilotlsp.InlineEdit[]
---@param ns_id integer
function M._display_next_suggestion(edits, ns_id)
  local state = vim.b[vim.api.nvim_get_current_buf()].nes_state
  if state then
    M.clear_suggestion(vim.api.nvim_get_current_buf(), ns_id)
  end

  if not edits or #edits == 0 then
    -- vim.notify("No suggestion available", vim.log.levels.INFO)
    return
  end
  local bufnr = vim.uri_to_bufnr(edits[1].textDocument.uri)
  local suggestion = edits[1]

  local lines = M._calculate_lines(suggestion)

  if lines.deleted_lines_count > 0 then
    -- Deleted range red highlight
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.delete_extmark.row, 0, {
      hl_group = "NesDelete",
      end_row = lines.delete_extmark.end_row,
    })
  end
  if lines.added_lines_count > 0 then
    local text = trim_end(edits[1].text)
    local virt_lines = require("copilot.nes.util").hl_text_to_virt_lines(text, vim.bo[bufnr].filetype)

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.virt_lines_extmark.row, 0, {
      virt_lines = virt_lines,
    })
  end

  vim.b[bufnr].nes_state = suggestion

  vim.b[bufnr].nes_state = suggestion

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    buffer = bufnr,
    callback = function()
      if not vim.b.nes_state then
        return true
      end

      M.clear_suggestion(bufnr, ns_id)
      return true
    end,
  })
end

return M
