local config = require("copilot.config")

local unpack = unpack or table.unpack

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
      -- reflects version of github/copilot.vim
      version = "1.13.0",
    },
  }
  return info
end

local copilot_lua_version = nil
function M.get_copilot_lua_version()
  if not copilot_lua_version then
    local plugin_version_ok, plugin_version = pcall(function()
      local plugin_dir = vim.fn.fnamemodify(M.get_copilot_path(), ":h:h")
      return vim.fn.systemlist(string.format("cd %s && git rev-parse HEAD", plugin_dir))[1]
    end)
    copilot_lua_version = plugin_version_ok and plugin_version or "dev"
  end
  return copilot_lua_version
end

-- use `require("copilot.client").get()`
---@deprecated
M.get_copilot_client = function()
  return require("copilot.client").get()
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
  local ft_disabled, ft_disabled_reason = is_ft_disabled(vim.bo.filetype, config.get("filetypes"))

  if ft_disabled then
    return not ft_disabled, ft_disabled_reason
  end

  if not vim.bo.buflisted then
    return false, "buffer not 'buflisted'"
  end

  if not vim.bo.buftype == "" then
    return false, "buffer 'buftype' is " .. vim.bo.buftype
  end

  return true
end

-- use `require("copilot.client").buf_is_attached()`
---@deprecated
function M.is_attached()
  return require("copilot.client").buf_is_attached(0)
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

-- use `require("copilot.util").get_doc_params()`
---@deprecated
M.get_completion_params = function(opts)
  return M.get_doc_params(opts)
end

---@return copilot_editor_configuration
function M.get_editor_configuration()
  local conf = config.get()

  local filetypes = vim.deepcopy(conf.filetypes)

  if filetypes["*"] == nil then
    filetypes = vim.tbl_deep_extend("keep", filetypes, internal_filetypes)
  end

  ---@type string[]
  local disabled_filetypes = vim.tbl_filter(function(ft)
    return filetypes[ft] == false
  end, vim.tbl_keys(filetypes))
  table.sort(disabled_filetypes)

  return {
    enableAutoCompletions = not not (conf.panel.enabled or conf.suggestion.enabled),
    disabledLanguages = vim.tbl_map(function(ft)
      return { languageId = ft }
    end, disabled_filetypes),
  }
end

---@param str string
local function url_decode(str)
  return vim.fn.substitute(str, [[%\(\x\x\)]], [[\=iconv(nr2char("0x".submatch(1)), "utf-8", "latin1")]], "g")
end

---@return copilot_network_proxy|nil
function M.get_network_proxy()
  local proxy_uri = vim.g.copilot_proxy

  if type(proxy_uri) ~= "string" then
    return
  end

  proxy_uri = string.gsub(proxy_uri, "^[^:]+://", "")

  ---@type string|nil, string|nil
  local user_pass, host_port = unpack(vim.split(proxy_uri, "@", { plain = true, trimempty = true }))

  if not host_port then
    host_port = user_pass --[[@as string]]
    user_pass = nil
  end

  local query_string
  host_port, query_string = unpack(vim.split(host_port, "?", { plain = true, trimempty = true }))

  local rejectUnauthorized = vim.g.copilot_proxy_strict_ssl

  if query_string then
    local query_params = vim.split(query_string, "&", { plain = true, trimempty = true })
    for _, query_param in ipairs(query_params) do
      local strict_ssl = string.match(query_param, "strict_?ssl=(.*)")

      if string.find(strict_ssl, "^[1t]") then
        rejectUnauthorized = true
        break
      end

      if string.find(strict_ssl, "^[0f]") then
        rejectUnauthorized = false
        break
      end
    end
  end

  local host, port = unpack(vim.split(host_port, ":", { plain = true, trimempty = true }))
  local username, password

  if user_pass then
    username, password = unpack(vim.split(user_pass, ":", { plain = true, trimempty = true }))
    username, password = username and url_decode(username), password and url_decode(password)
  end

  return {
    host = host,
    port = tonumber(port or 80),
    username = username,
    password = password,
    rejectUnauthorized = rejectUnauthorized,
  }
end

---@deprecated
M.get_copilot_path = function()
  local copilot_path = vim.api.nvim_get_runtime_file("copilot/index.js", false)[1]
  if vim.fn.filereadable(copilot_path) ~= 0 then
    return copilot_path
  else
    print("[Copilot] could not read" .. copilot_path)
  end
end

---@deprecated
M.auth = function()
  require("copilot.auth").signin()
end

---@param str string
---@return integer
function M.strutf16len(str)
  return vim.fn.strchars(vim.fn.substitute(str, [==[\\%#=2[^\u0001-\uffff]]==], "  ", "g"))
end

if vim.fn.exists("*strutf16len") == 1 then
  M.strutf16len = vim.fn.strutf16len
end

return M
