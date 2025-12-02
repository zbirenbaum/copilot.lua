local config = require("copilot.config")
local logger = require("copilot.logger")

local M = {
  VAR_ATTACH_STATUS = "copilot_lua_attach_status",
  VAR_PREVIOUS_FT = "copilot_lua_previous_ft",
  ATTACH_STATUS_MANUALLY_DETACHED = "manually detached",
  ATTACH_STATUS_FORCE_ATTACHED = "force attached",
  ATTACH_STATUS_ATTACHED = "attached",
  ATTACH_STATUS_NOT_ATTACHED_PREFIX = "not attached based on ",
  ATTACH_STATUS_NOT_YET_REQUESTED = "attach not yet requested",
}

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
      version = "1.399.0",
    },
  }
  return info
end

local copilot_lua_version = nil

function M.get_copilot_lua_version()
  if not copilot_lua_version then
    local plugin_version_ok, plugin_version = pcall(function()
      local plugin_dir = M.get_plugin_path()
      return vim.fn.systemlist(string.format("git -C %s rev-parse HEAD", plugin_dir))[1]
    end)
    copilot_lua_version = plugin_version_ok and plugin_version or "dev"
  end
  return copilot_lua_version
end

---@param bufnr? integer
---@return boolean should_attach
---@return string? no_attach_reason
function M.should_attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, "Invalid buffer"
  end

  local ft = config.filetypes
  local ft_disabled, ft_disabled_reason = require("copilot.client.filetypes").is_ft_disabled(vim.bo[bufnr].filetype, ft)

  if ft_disabled then
    return not ft_disabled, ft_disabled_reason
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local conf_attach = config.should_attach(bufnr, bufname)

  if not conf_attach then
    return false, "should_attach config"
  end

  return true
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

-- Used by copilot.cmp so watch out if moving it
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

function M.get_plugin_path()
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

---@param bufnr integer
---@param status string
function M.set_buffer_attach_status(bufnr, status)
  vim.api.nvim_buf_set_var(bufnr, M.VAR_ATTACH_STATUS, status)
end

---@param bufnr integer
---@return string
function M.get_buffer_attach_status(bufnr)
  local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, M.VAR_ATTACH_STATUS)
  return (ok and result) or M.ATTACH_STATUS_NOT_YET_REQUESTED
end

---@param bufnr integer
---@param filetype string
function M.set_buffer_previous_ft(bufnr, filetype)
  vim.api.nvim_buf_set_var(bufnr, M.VAR_PREVIOUS_FT, filetype)
end

---@param bufnr integer
---@return string|nil
function M.get_buffer_previous_ft(bufnr)
  local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, M.VAR_PREVIOUS_FT)
  return (ok and result) or nil
end

---@param cmd string|string[]
---@param append string|string[]
---@return string[]
function M.append_command(cmd, append)
  local full_cmd = {}

  -- first append the base command
  if type(cmd) == "string" then
    table.insert(full_cmd, cmd)
  elseif type(cmd) == "table" then
    for _, part in ipairs(cmd) do
      if part ~= nil then
        table.insert(full_cmd, part)
      end
    end
  end

  -- then append the additional parts
  if type(append) == "string" then
    table.insert(full_cmd, append)
  elseif type(append) == "table" then
    for _, part in ipairs(append) do
      if part ~= nil then
        table.insert(full_cmd, part)
      end
    end
  end

  return full_cmd
end

---@param server_path string
---@param server_type ServerType
---@param node_version string|nil
---@return string[]
function M.get_node_args(server_path, server_type, node_version)
  local args = { server_path, "--stdio" }
  local node_version_major = tonumber(string.match(node_version or "", "^(%d+)%.")) or 0
  if (server_type == "nodejs") and (node_version_major < 25) then
    table.insert(args, 1, "--experimental-sqlite")
  end

  return args
end

return M
