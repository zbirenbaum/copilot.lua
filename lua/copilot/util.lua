local M = {}

local id = 0
function M.get_next_id()
  id = id + 1
  return id
end

---@return copilot_set_editor_info_params
function M.get_editor_info()
  local info = {
    editorInfo = {
      name = "Neovim",
      version = string.match(vim.fn.execute("version"), "NVIM v(%S+)"),
    },
    editorPluginInfo = {
      name = "copilot.vim",
      version = '1.5.3',
    },
  }
  return info
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

local eol_by_fileformat = {
  unix = "\n",
  dos = "\r\n",
  mac = "\r",
}

local language_normalization_map = {
  text = "plaintext",
  javascriptreact = "javascript",
  jsx = "javascript",
  typescriptreact = "typescript",
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

M.get_copilot_path = function(plugin_path)
  for _, loc in ipairs({ "/opt", "/start", "" }) do
    local copilot_path = plugin_path .. loc .. "/copilot.lua/copilot/index.js"
    if vim.fn.filereadable(copilot_path) ~= 0 then
      return copilot_path
    end
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
