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

return M
