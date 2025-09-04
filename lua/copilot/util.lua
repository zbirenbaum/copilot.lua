local config = require("copilot.config")
local logger = require("copilot.logger")

local M = {}
VAR_ATTACH_STATUS = "copilot_lua_attach_status"
VAR_PREVIOUS_FT = "copilot_lua_previous_ft"
ATTACH_STATUS_MANUALLY_DETACHED = "manually detached"
ATTACH_STATUS_FORCE_ATTACHED = "force attached"
ATTACH_STATUS_ATTACHED = "attached"
ATTACH_STATUS_NOT_ATTACHED_PREFIX = "not attached based on "
ATTACH_STATUS_NOT_YET_REQUESTED = "attach not yet requested"

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
      version = "1.367.0",
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

---@param mode string
---@param key string|false
function M.unset_keymap_if_exists(mode, key)
  if not key then
    return
  end

  local ok, err = pcall(vim.api.nvim_del_keymap, mode, key)

  if not ok then
    local suggestion_keymaps = config.suggestion.keymap or {}
    local panel_keymaps = config.panel.keymap or {}
    local found = false

    for _, tbl in ipairs({ suggestion_keymaps, panel_keymaps }) do
      for _, v in pairs(tbl) do
        if v == key then
          if found then
            logger.error("Keymap " .. key .. " is used for two different actions, please review your configuration.")
            return
          else
            found = true
          end
        end
      end
    end

    logger.error("Could not unset keymap for " .. mode .. " " .. key .. ": " .. err)
  end
end

---@param bufnr integer
---@param status string
function M.set_buffer_attach_status(bufnr, status)
  vim.api.nvim_buf_set_var(bufnr, VAR_ATTACH_STATUS, status)
end

---@param bufnr integer
---@return string
function M.get_buffer_attach_status(bufnr)
  local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, VAR_ATTACH_STATUS)
  return (ok and result) or ATTACH_STATUS_NOT_YET_REQUESTED
end

---@param bufnr integer
---@param filetype string
function M.set_buffer_previous_ft(bufnr, filetype)
  vim.api.nvim_buf_set_var(bufnr, VAR_PREVIOUS_FT, filetype)
end

---@param bufnr integer
---@return string
function M.get_buffer_previous_ft(bufnr)
  local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, VAR_PREVIOUS_FT)
  return (ok and result) or ""
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

return M
