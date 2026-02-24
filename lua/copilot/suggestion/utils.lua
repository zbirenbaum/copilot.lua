local M = {}

function M.remove_common_suffix(str, suggestion)
  if str == "" or suggestion == "" then
    return suggestion
  end

  local str_len = #str
  local suggestion_len = #suggestion
  local shorter_len = math.min(str_len, suggestion_len)

  local matching = 0
  for i = 1, shorter_len do
    local str_char = string.sub(str, str_len - i + 1, str_len - i + 1)
    local suggestion_char = string.sub(suggestion, suggestion_len - i + 1, suggestion_len - i + 1)

    if str_char == suggestion_char then
      matching = matching + 1
    else
      break
    end
  end

  if matching == 0 then
    return suggestion
  end

  return string.sub(suggestion, 1, suggestion_len - matching)
end

---Compute the display text for the first line of a suggestion.
---Handles indentation mismatches and range.start.character > 0.
---@param suggestion_first_line string
---@param range_start_char number
---@param cursor_col number 1-based cursor column (vim.fn.col("."))
---@param current_line string
---@return string display_text
---@return number outdent
function M.get_display_adjustments(suggestion_first_line, range_start_char, cursor_col, current_line)
  local prefix = string.sub(current_line, 1, range_start_char)
  local choice_text = prefix .. suggestion_first_line

  local typed = string.sub(current_line, 1, cursor_col - 1)

  if typed == "" then
    return choice_text, 0
  end

  if typed:match("^%s+$") then
    local choice_ws = choice_text:match("^(%s*)") or ""
    local typed_len = #typed
    local choice_ws_len = #choice_ws

    if typed_len <= choice_ws_len then
      return string.sub(choice_text, typed_len + 1), 0
    else
      return string.sub(choice_text, choice_ws_len + 1), typed_len - choice_ws_len
    end
  end

  if string.sub(choice_text, 1, #typed) == typed then
    return string.sub(choice_text, #typed + 1), 0
  end

  return "", 0
end

return M
