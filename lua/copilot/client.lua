local M = { params = {} }

local register_autocmd = function ()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = vim.schedule_wrap(M.buf_attach_copilot),
  })
end

M.buf_attach_copilot = function()
  if vim.tbl_contains(M.params.ft_disable, vim.bo.filetype) then return end
  if not vim.bo.buflisted or not vim.bo.buftype == "" then return end
  local name = M.params.server_opts_overrides.name or "copilot"
  local client = vim.lsp.get_active_clients({name=name})[1]
  if client and not vim.lsp.buf_is_attached(0, client.id) then
    vim.lsp.buf_attach_client(0, client.id)
    client.completion_function = M.params.extensions
  end
end

M.merge_server_opts = function (params)
  return vim.tbl_deep_extend("force", {
    cmd = { "node", require("copilot.util").get_copilot_path(params.plugin_manager_path) },
    name = "copilot",
    root_dir = vim.loop.cwd(),
    autostart = true,
    on_init = function(_, _)
      vim.schedule(M.buf_attach_copilot)
      vim.schedule(register_autocmd)
    end,
  }, params.server_opts_overrides or {})
end

M.start = function(params)
  M.params = params
  vim.lsp.start_client(M.merge_server_opts(params))
end

return M
