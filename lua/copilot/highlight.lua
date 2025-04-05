local M = {
  group = {
    CopilotAnnotation = "CopilotAnnotation",
    CopilotSuggestion = "CopilotSuggestion",
  },
}

local links = {
  [M.group.CopilotAnnotation] = "Comment",
  [M.group.CopilotSuggestion] = "Comment",
}

function M.setup()
  -- Some environments will load themes after plugins (like ChadNv) so we do it as late as possible
  vim.schedule(function()
    for from_group, to_group in pairs(links) do
      local ok, existing = pcall(vim.api.nvim_get_hl, 0, { name = from_group })
      if not ok or vim.tbl_isempty(existing) then
        vim.api.nvim_set_hl(0, from_group, { link = to_group })
      end
    end
  end)
end

return M
