local M = {
  internal_filetypes = {
    yaml = false,
    markdown = false,
    help = false,
    gitcommit = false,
    gitrebase = false,
    hgcommit = false,
    svn = false,
    cvs = false,
    ["."] = false,
  },
}

local language_normalization_map = {
  bash = "shellscript",
  bst = "bibtex",
  cs = "csharp",
  cuda = "cuda-cpp",
  dosbatch = "bat",
  dosini = "ini",
  gitcommit = "git-commit",
  gitrebase = "git-rebase",
  make = "makefile",
  objc = "objective-c",
  objcpp = "objective-cpp",
  ps1 = "powershell",
  raku = "perl6",
  sh = "shellscript",
  text = "plaintext",
}

function M.language_for_file_type(filetype)
  -- trim filetypes after dot, e.g. `yaml.gotexttmpl` -> `yaml`
  local ft = string.gsub(filetype, "%..*", "")
  if not ft or ft == "" then
    ft = "text"
  end
  return language_normalization_map[ft] or ft
end

---@param filetype_enabled boolean|fun():boolean
local function resolve_filetype_enabled(filetype_enabled)
  if type(filetype_enabled) == "function" then
    return filetype_enabled()
  end
  return filetype_enabled
end

---@param ft string
---@param filetypes table<string, boolean>
---@return boolean ft_disabled
---@return string? ft_disabled_reason
function M.is_ft_disabled(ft, filetypes)
  if filetypes[ft] ~= nil then
    return not resolve_filetype_enabled(filetypes[ft]),
      string.format("'filetype' %s rejected by config filetypes[%s]", ft, ft)
  end

  local short_ft = string.gsub(ft, "%..*", "")

  if filetypes[short_ft] ~= nil then
    return not resolve_filetype_enabled(filetypes[short_ft]),
      string.format("'filetype' %s rejected by config filetypes[%s]", ft, short_ft)
  end

  if filetypes["*"] ~= nil then
    return not resolve_filetype_enabled(filetypes["*"]),
      string.format("'filetype' %s rejected by config filetypes[%s]", ft, "*")
  end

  if M.internal_filetypes[short_ft] ~= nil then
    return not M.internal_filetypes[short_ft],
      string.format("'filetype' %s rejected by internal_filetypes[%s]", ft, short_ft)
  end

  return false
end

return M
