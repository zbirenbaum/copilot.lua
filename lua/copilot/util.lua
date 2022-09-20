local M = {}

local id = 0
function M.get_next_id()
  id = id + 1
  return id
end

-- keep for debugging reasons
M.get_editor_info = function ()
  local info = vim.empty_dict()
  info.editorInfo = vim.empty_dict()
  info.editorInfo.name = 'Neovim'
  info.editorInfo.version = '0.8.0-dev-809-g7dde6d4fd'
  info.editorPluginInfo = vim.empty_dict()
  info.editorPluginInfo.name = 'copilot.vim'
  info.editorPluginInfo.version = '1.5.3'
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

local format_pos = function()
  local pos = vim.api.nvim_win_get_cursor(0)
  return { character = pos[2], line = pos[1] - 1 }
end

local get_relfile = function()
  local file, _ = string.gsub(vim.api.nvim_buf_get_name(0), vim.loop.cwd() .. "/", "")
  return file
end

M.get_copilot_client = function()
 --  vim.lsp.get_active_clients({name="copilot"}) -- not in 0.7
  for _, client in pairs(vim.lsp.get_active_clients()) do
    if client.name == "copilot" then return client end
  end
end

local normalize_ft = function (ft)
  local resolve_map = {
    text = "plaintext",
    javascriptreact = "javascript",
    jsx = "javascript",
    typescriptreact = "typescript",
  }
  if not ft or ft == '' then
    return 'plaintext'
  end
  return resolve_map[ft] or ft
end

M.get_completion_params = function(opts)
  local rel_path = get_relfile()
  local uri = vim.uri_from_bufnr(0)
  local params = {
    doc = {
      source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"),
      relativePath = rel_path,
      languageId = normalize_ft(vim.api.nvim_buf_get_option(0, 'filetype')),
      insertSpaces = vim.o.expandtab,
      tabsize = vim.bo.shiftwidth,
      indentsize = vim.bo.shiftwidth,
      position = format_pos(),
      path = vim.api.nvim_buf_get_name(0),
      uri = uri,
    },
    textDocument = {
      languageId = vim.bo.filetype,
      relativePath = rel_path,
      uri = uri,
    }
  }
  params.position = params.doc.position
  if opts then params.doc = vim.tbl_deep_extend('keep', params.doc, opts) end
  return params
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
