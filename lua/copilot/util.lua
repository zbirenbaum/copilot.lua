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
      name = "copilot.vim",
      version = "1.7.0",
    },
  }
  return info
end

local copilot_lua_version = nil
function M.get_copilot_lua_version()
  if not copilot_lua_version then
    local plugin_version_ok, plugin_version = pcall(function()
      return vim.fn.systemlist("git rev-parse HEAD")[1]
    end)
    copilot_lua_version = plugin_version_ok and plugin_version or "dev"
  end
  return copilot_lua_version
end

-- keep for debugging reasons
local get_capabilities = function ()
  return {
    capabilities = {
      textDocumentSync = {
        change = 2,
        openClose = true
      },
      workspace = {
        workspaceFolders = {
          changeNotifications = true,
          supported = true
        }
      }
    }
  }
end

M.get_copilot_client = function()
 --  vim.lsp.get_active_clients({name="copilot"}) -- not in 0.7
  for _, client in pairs(vim.lsp.get_active_clients()) do
    if client.name == "copilot" then return client end
  end
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

---@param ft string
---@param filetypes table<string, boolean>
---@return boolean ft_disabled
---@return string? ft_disabled_reason
local function is_ft_disabled(ft, filetypes)
  if filetypes[ft] ~= nil then
    return not filetypes[ft], string.format("'filetype' %s rejected by config filetypes[%s]", ft, ft)
  end

  local short_ft = string.gsub(ft, "%..*", "")

  if filetypes[short_ft] ~= nil then
    return not filetypes[short_ft], string.format("'filetype' %s rejected by config filetypes[%s]", ft, short_ft)
  end

  if filetypes["*"] ~= nil then
    return not filetypes["*"], string.format("'filetype' %s rejected by config filetypes[%s]", ft, "*")
  end

  if internal_filetypes[short_ft] ~= nil then
    return not internal_filetypes[short_ft], string.format("'filetype' %s rejected by internal_filetypes[%s]", ft, short_ft)
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

function M.is_attached(client)
  client = client or M.get_copilot_client()
  return client and vim.lsp.buf_is_attached(0, client.id) or false
end

local eol_by_fileformat = {
  unix = "\n",
  dos = "\r\n",
  mac = "\r",
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

local function language_for_file_type(filetype)
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
    languageId = language_for_file_type(vim.bo.filetype),
    path = absolute,
    uri = params.textDocument.uri,
    relativePath = relative_path(absolute),
    insertSpaces = vim.o.expandtab,
    tabSize = vim.fn.shiftwidth(),
    indentSize = vim.fn.shiftwidth(),
    position = params.position,
  }

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if vim.bo.endofline and vim.bo.fixendofline then
    table.insert(lines, "")
  end
  doc.source = table.concat(lines, eol_by_fileformat[vim.bo.fileformat] or "\n")

  return doc
end

function M.get_doc_params(overrides)
  overrides = overrides or {}

  local params = vim.tbl_extend("keep", {
    doc = vim.tbl_extend("force", M.get_doc(), overrides.doc or {}),
  }, overrides)
  params.textDocument = {
    uri = params.doc.uri,
    languageId = params.doc.languageId,
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
    disabledLanguages = disabled_filetypes,
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
  }
end

M.get_copilot_path = function()
  local copilot_path = vim.api.nvim_get_runtime_file('copilot/index.js', false)[1]
  if vim.fn.filereadable(copilot_path) ~= 0 then
    return copilot_path
  else
    print("[Copilot] could not read" .. copilot_path)
  end
end

M.auth = function ()
  local c = M.get_copilot_client()
  if not c then
    print("[Copilot] not running yet!")
    return
  end
  require("copilot.auth").setup(c)
end


return M
