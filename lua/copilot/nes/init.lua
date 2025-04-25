local nes_ui = require("copilot.nes.ui")
local utils = require("copilot.nes.util")
local api = require("copilot.api")
local c = require("copilot.client")

local M = {}

local nes_ns = vim.api.nvim_create_namespace("copilot-nes")

---@param err lsp.ResponseError?
---@param result copilotlsp.copilotInlineEditResponse
local function handle_nes_response(err, result)
  if err then
    -- vim.notify(err.message)
    return
  end
  for _, edit in ipairs(result.edits) do
    --- Convert to textEdit fields
    edit.newText = edit.text
  end
  nes_ui._display_next_suggestion(result.edits, nes_ns)
end

--- Requests the NextEditSuggestion from the current cursor position
function M.request_nes()
  local pos_params = vim.lsp.util.make_position_params(0, "utf-16")
  local version = vim.lsp.util.buf_versions[vim.api.nvim_get_current_buf()]
  ---@diagnostic disable-next-line: inject-field
  pos_params.textDocument.version = version
  c.use_client(function(client)
    api.request(client, "textDocument/copilotInlineEdit", pos_params, handle_nes_response)
  end)
end

--- Walks the cursor to the start of the edit.
--- This function returns false if there is no edit to apply or if the cursor is already at the start position of the
--- edit.
---@param bufnr? integer
---@return boolean --if the cursor walked
function M.walk_cursor_start_edit(bufnr)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
  ---@type copilotlsp.InlineEdit
  local state = vim.b[bufnr].nes_state
  if not state then
    return false
  end

  local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  if cursor_row - 1 ~= state.range.start.line then
    vim.b[bufnr].nes_jump = true
    ---@type lsp.Location
    local jump_loc_before = {
      uri = state.textDocument.uri,
      range = {
        start = state.range["start"],
        ["end"] = state.range["start"],
      },
    }
    return vim.lsp.util.show_document(jump_loc_before, "utf-16", { focus = true })
  else
    return false
  end
end

--- Walks the cursor to the end of the edit.
--- This function returns false if there is no edit to apply or if the cursor is already at the end position of the
--- edit
---@param bufnr? integer
---@return boolean --if the cursor walked
function M.walk_cursor_end_edit(bufnr)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
  ---@type copilotlsp.InlineEdit
  local state = vim.b[bufnr].nes_state
  if not state then
    return false
  end

  ---@type lsp.Location
  local jump_loc_after = {
    uri = state.textDocument.uri,
    range = {
      start = state.range["end"],
      ["end"] = state.range["end"],
    },
  }
  --NOTE: If last line is deletion, then this may be outside of the buffer
  vim.schedule(function()
    pcall(vim.lsp.util.show_document, jump_loc_after, "utf-16", { focus = true })
  end)
  return true
end

--- This function applies the pending nes edit to the current buffer and then clears the marks for the pending
--- suggestion
---@param bufnr? integer
---@return boolean --if the nes was applied
function M.apply_pending_nes(bufnr)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()

  ---@type copilotlsp.InlineEdit
  local state = vim.b[bufnr].nes_state
  if not state then
    return false
  end
  vim.schedule(function()
    utils.apply_inline_edit(state)
    vim.b[bufnr].nes_jump = false
    nes_ui.clear_suggestion(bufnr, nes_ns)
  end)
  return true
end

return M
