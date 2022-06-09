local fn = vim.fn
local lsp = require("copilot.dev.lsp")
local util = require("copilot.util")
local bin = util.get_copilot_path(fn.stdpath("data") .. "/site/pack/packer")

local buf_attach_copilot = function()
  if not vim.bo.buflisted or not vim.bo.buftype == "" then return end
  local client_id = util.find_copilot_client()
  local buf_clients = vim.lsp.buf_get_clients(0)
  if not buf_clients and client_id or (client_id and not buf_clients[client_id]) then
    vim.lsp.buf_attach_client(0, client_id)
  end
end

local attach_client = function ()
  local client_id = util.find_copilot_client()
  local buf_clients = vim.lsp.buf_get_clients(0)
  if not buf_clients and client_id or (client_id and not buf_clients[client_id]) then
    vim.lsp.buf_attach_client(0, client_id)
  end
end

local client_id = vim.lsp.start_client({
  cmd = { "node",  bin},
  name = "copilot",
  trace = "messages",
  root_dir = vim.loop.cwd(),
  autostart = true,
  on_init = function(_, _)
    vim.schedule(attach_client)
  end,
  on_attach = function()
    vim.schedule(attach_client)
    vim.schedule(function()
      require("copilot_cmp")._on_insert_enter()
    end)
  end,
  handlers = {
  }
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  callback = vim.schedule_wrap(buf_attach_copilot),
})

return client_id
