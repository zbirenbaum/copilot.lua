local M = { params = {} }
local util = require("copilot.util")

M.buf_attach_copilot = function()
  if vim.tbl_contains(M.params.ft_disable, vim.bo.filetype) then return end
  if not vim.bo.buflisted or not vim.bo.buftype == "" then return end
  local client_id = util.find_copilot_client()
  local buf_clients = vim.lsp.buf_get_clients(0)
  if not buf_clients and client_id or (client_id and not buf_clients[client_id]) then
    vim.lsp.buf_attach_client(0, client_id)
  end
end

local register_autocmd = function ()
  if vim.fn.has("nvim-0.7") > 0 then
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      callback = vim.schedule_wrap(M.buf_attach_copilot),
    })
  else
    vim.cmd("au BufEnter * lua vim.schedule(function() require('copilot.client').buf_attach_copilot() end)")
  end
end

M.merge_server_opts = function (params)
  return vim.tbl_deep_extend("force", {
    cmd = { "node", require("copilot.util").get_copilot_path(params.plugin_manager_path) },
    name = "copilot",
    trace = "messages",
    root_dir = vim.loop.cwd(),
    autostart = true,
    on_init = function(_, _)
      vim.schedule(M.buf_attach_copilot)
      vim.schedule(register_autocmd)
    end,
    handlers = params.panel and {
      ["PanelSolution"] = params.panel.save_completions,
    },
    settings = {
      advanced = {
        listCount = 10, -- #completions for panel
        inlineSuggestCount = 1, -- #completions for getCompletions
      }
    },
  }, params.server_opts_overrides or {})
end

M.start = function(params)
  M.params = params
  local client_id = vim.lsp.start_client(M.merge_server_opts(params))
  local client = vim.lsp.get_client_by_id(client_id)
  return { client_id, client }
end

return M
