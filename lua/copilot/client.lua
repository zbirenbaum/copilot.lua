local api = require("copilot.api")
local util = require("copilot.util")

local M = { params = {} }

local copilot_node_version = nil
function M.get_node_version()
  if not copilot_node_version then
    copilot_node_version = string.match(table.concat(vim.fn.systemlist(M.params.copilot_node_command .. " --version", nil, false)), "v(%S+)")
  end
  return copilot_node_version
end

local register_autocmd = function()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = vim.schedule_wrap(M.buf_attach_copilot),
  })
end

---@param force? boolean
function M.buf_attach(client, force)
  if not force and not util.should_attach(M.params.filetypes) then
    return
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

M.merge_server_opts = function(params)
  return vim.tbl_deep_extend("force", {
    cmd = {
      params.copilot_node_command,
      require("copilot.util").get_copilot_path(),
    },
    cmd_cwd = vim.fn.expand("~"),
    root_dir = vim.loop.cwd(),
    name = "copilot",
    autostart = true,
    single_file_support = true,
    on_init = function(client)
      vim.schedule(function ()
        ---@type copilot_set_editor_info_params
        local set_editor_info_params = util.get_editor_info()
        set_editor_info_params.editorInfo.version = set_editor_info_params.editorInfo.version .. ' + Node.js ' .. M.get_node_version()
        set_editor_info_params.editorConfiguration = util.get_editor_configuration()
        api.set_editor_info(client, set_editor_info_params)
      end)
      vim.schedule(M.buf_attach_copilot)
      vim.schedule(register_autocmd)
    end,
    handlers = {
      PanelSolution = api.handlers.PanelSolution,
      PanelSolutionsDone = api.handlers.PanelSolutionsDone,
      statusNotification = api.handlers.statusNotification,
    },
  }, params.server_opts_overrides or {})
end

M.start = function(params)
  M.params = params
  --- for backward compatibility
  if M.params.ft_disable then
    for _, disabled_ft in ipairs(M.params.ft_disable) do
      M.params.filetypes[disabled_ft] = false
    end
  end

  if not M.params.copilot_node_command then
    M.params.copilot_node_command = "node"
  end

  vim.lsp.start_client(M.merge_server_opts(params))
end

return M
