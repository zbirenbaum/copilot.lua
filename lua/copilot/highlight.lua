local mod = {
  group = {
    CopilotAnnotation = "CopilotAnnotation",
    CopilotSuggestion = "CopilotSuggestion",
  },
}

local links = {
  [mod.group.CopilotAnnotation] = "Comment",
  [mod.group.CopilotSuggestion] = "Comment",
}

function mod.setup()
  for from_group, to_group in pairs(links) do
    vim.api.nvim_command("highlight default link " .. from_group .. " " .. to_group)
  end
end

return mod
