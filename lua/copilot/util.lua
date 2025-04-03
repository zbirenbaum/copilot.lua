local config = require("copilot.config")
local logger = require("copilot.logger")

local M = {}

local id = 0
function M.get_next_id()
  id = id + 1
  return id
end

---@return { editorInfo: copilot_editor_info, editorPluginInfo: copilot_editor_plugin_info }
function M.get_editor_info()
  local info = {
    editorInfo = {
      name = "Neovim",
      version = string.match(vim.fn.execute("version"), "NVIM v(%S+)"),
    },
    editorPluginInfo = {
      name = "copilot.lua",
      -- reflects version of github/copilot-language-server-release
      version = "1.296.0",
    },
  }
  return info
end

local copilot_lua_version = nil
function M.get_copilot_lua_version()
  if not copilot_lua_version then
    local plugin_version_ok, plugin_version = pcall(function()
      local plugin_dir = M.get_plugin_path()
      return vim.fn.systemlist(string.format("cd %s && git rev-parse HEAD", plugin_dir))[1]
    end)
    copilot_lua_version = plugin_version_ok and plugin_version or "dev"
  end
  return copilot_lua_version
end

local internal_filetypes = {
  yaml = false,
  markdown = false,
  help = false,
  gitcommit = false,
  gitrebase = false,
  hgcommit = false,
  svn = false,
  cvs = false,
  ["."] = false,
}

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
local function is_ft_disabled(ft, filetypes)
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

  if internal_filetypes[short_ft] ~= nil then
    return not internal_filetypes[short_ft],
      string.format("'filetype' %s rejected by internal_filetypes[%s]", ft, short_ft)
  end

  return false
end

---@return boolean should_attach
---@return string? no_attach_reason
function M.should_attach()
  local ft = config.config.filetypes
  local ft_disabled, ft_disabled_reason = is_ft_disabled(vim.bo.filetype, ft)

  if ft_disabled then
    return not ft_disabled, ft_disabled_reason
  end

  return true
end

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

local function relative_path(absolute)
  local relative = vim.fn.fnamemodify(absolute, ":.")
  if string.sub(relative, 0, 1) == "/" then
    return vim.fn.fnamemodify(absolute, ":t")
  end
  return relative
end

function M.get_doc()
  local absolute = vim.api.nvim_buf_get_name(0)
  local params = vim.lsp.util.make_position_params(0, "utf-16") -- copilot server uses utf-16
  local doc = {
    uri = params.textDocument.uri,
    version = vim.api.nvim_buf_get_var(0, "changedtick"),
    relativePath = relative_path(absolute),
    insertSpaces = vim.o.expandtab,
    tabSize = vim.fn.shiftwidth(),
    indentSize = vim.fn.shiftwidth(),
    position = params.position,
  }

  return doc
end

function M.get_doc_params(overrides)
  overrides = overrides or {}

  local params = vim.tbl_extend("keep", {
    doc = vim.tbl_extend("force", M.get_doc(), overrides.doc or {}),
  }, overrides)
  params.textDocument = {
    uri = params.doc.uri,
    version = params.doc.version,
    relativePath = params.doc.relativePath,
  }
  params.position = params.doc.position

  return params
end

---@return copilot_workspace_configurations
function M.get_workspace_configurations()
  local conf = config.config
  local filetypes = vim.deepcopy(conf.filetypes) --[[@as table<string, boolean>]]

  if filetypes["*"] == nil then
    filetypes = vim.tbl_deep_extend("keep", filetypes, internal_filetypes)
  end

  local copilot_model = conf and conf.copilot_model ~= "" and conf.copilot_model or ""

  ---@type string[]
  local disabled_filetypes = vim.tbl_filter(function(ft)
    return filetypes[ft] == false
  end, vim.tbl_keys(filetypes))
  table.sort(disabled_filetypes)

  return {
    settings = {
      github = {
        copilot = {
          selectedCompletionModel = copilot_model,
        },
      },
      enableAutoCompletions = not not (conf.panel.enabled or conf.suggestion.enabled),
      disabledLanguages = vim.tbl_map(function(ft)
        return { languageId = ft }
      end, disabled_filetypes),
    },
  }
end

M.get_plugin_path = function()
  local copilot_path = vim.api.nvim_get_runtime_file("lua/copilot/init.lua", false)[1]
  if vim.fn.filereadable(copilot_path) ~= 0 then
    return vim.fn.fnamemodify(copilot_path, ":h:h:h")
  else
    logger.error("could not read" .. copilot_path)
  end
end

---@param str string
---@return integer
function M.strutf16len(str)
  if vim.fn.exists("*strutf16len") == 1 then
    return vim.fn.strutf16len(str)
  else
    return vim.fn.strchars(vim.fn.substitute(str, [==[\\%#=2[^\u0001-\uffff]]==], "  ", "g"))
  end
end

---@return copilot_window_show_document_result
---@param result copilot_window_show_document
function M.show_document(_, result)
  logger.trace("window/showDocument:", result)
  local success, _ = pcall(vim.ui.open, result.uri)
  if not success then
    if vim.ui.open ~= nil then
      vim.api.nvim_echo({
        { "window/showDocument" },
        { vim.inspect({ _, result }) },
        { "\n", "NONE" },
      }, true, {})
      error("Unsupported OS: vim.ui.open exists but failed to execute.")
    else
      vim.api.nvim_echo({
        { "window/showDocument" },
        { vim.inspect({ _, result }) },
        { "\n", "NONE" },
      }, true, {})
      error("Unsupported Version: vim.ui.open requires Neovim >= 0.10")
    end
  end

  return {
    success = success,
  }
end

return M
