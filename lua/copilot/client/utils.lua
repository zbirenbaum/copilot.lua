local config = require("copilot.config")
local logger = require("copilot.logger")
local client_ft = require("copilot.client.filetypes")
local M = {}

---@param config_root_dir RootDirFuncOrString
function M.get_root_dir(config_root_dir)
  local root_dir --[[@as string]]

  if type(config_root_dir) == "function" then
    root_dir = config_root_dir()
  else
    root_dir = config_root_dir
  end

  if not root_dir or root_dir == "" then
    root_dir = "."
  end

  root_dir = vim.fn.fnamemodify(root_dir, ":p:h")
  return root_dir
end

---@return copilot_workspace_configurations
function M.get_workspace_configurations()
  local filetypes = vim.deepcopy(config.filetypes) --[[@as table<string, boolean>]]

  if filetypes["*"] == nil then
    filetypes = vim.tbl_deep_extend("keep", filetypes, client_ft.internal_filetypes)
  end

  local copilot_model = config and config.copilot_model ~= "" and config.copilot_model or ""

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
      enableAutoCompletions = not not (config.panel.enabled or config.suggestion.enabled),
      disabledLanguages = vim.tbl_map(function(ft)
        return { languageId = ft }
      end, disabled_filetypes),
    },
  }
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

M.wrap = vim.fn.has("nvim-0.11") == 1 and function(client)
  return client
end or function(client)
  -- stylua: ignore
  return setmetatable({
    notify = function(_, ...) return client.notify(...) end,
    request = function(_, ...) return client.request(...) end,
    cancel_request = function(_, ...) return client.cancel_request(...) end,
  }, { __index = client })
end

return M
