local api = require("copilot.api")
local util = require("copilot.util")

local M = { params = {} }

local register_autocmd = function ()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = vim.schedule_wrap(M.buf_attach_copilot),
  })
end

local default_filetypes = {
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

local function is_ft_disabled(ft)
  --- for backward compatibility
  if M.params.ft_disable and vim.tbl_contains(M.params.ft_disable, ft) then
    return true
  end

  if M.params.filetypes[ft] ~= nil then
    return not M.params.filetypes[ft]
  end

  local short_ft = string.gsub(ft, "%..*", "")

  if M.params.filetypes[short_ft] ~= nil then
    return not M.params.filetypes[short_ft]
  end

  if M.params.filetypes['*'] ~= nil then
    return not M.params.filetypes['*']
  end

  if default_filetypes[short_ft] ~= nil then
    return not default_filetypes[short_ft]
  end

  return false
end

---@param force? boolean
function M.buf_attach(client, force)
  if not force then
    if is_ft_disabled(vim.bo.filetype) then
      return
    end

    if not vim.bo.buflisted or not vim.bo.buftype == "" then
      return
    end
  end

  client = client or util.get_copilot_client()
  if client and not util.is_attached(client) then
    vim.lsp.buf_attach_client(0, client.id)

    ---@todo unknown property, remove this
    client.completion_function = M.params.extensions
  end
end

function M.buf_detach(client)
  client = client or util.get_copilot_client()
  if client and util.is_attached(client) then
    vim.lsp.buf_detach_client(0, client.id)
  end
end

M.buf_attach_copilot = function()
  M.buf_attach()
end

M.merge_server_opts = function (params)
  return vim.tbl_deep_extend("force", {
    cmd = {
      params.copilot_node_command or "node",
      require("copilot.util").get_copilot_path(params.plugin_manager_path)
    },
    cmd_cwd = vim.fn.expand('~'),
    root_dir = vim.loop.cwd(),
    name = "copilot",
    autostart = true,
    single_file_support = true,
    on_init = function(client)
      api.set_editor_info(client, util.get_editor_info())
      vim.schedule(M.buf_attach_copilot)
      vim.schedule(register_autocmd)
    end,
    handlers = {
      PanelSolution = api.handlers.PanelSolution,
      PanelSolutionsDone = api.handlers.PanelSolutionsDone,
      statusNotification = api.handlers.statusNotification,
    }
  }, params.server_opts_overrides or {})
end

M.start = function(params)
  M.params = params
  vim.lsp.start_client(M.merge_server_opts(params))
end

return M
