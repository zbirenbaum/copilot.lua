local user_data = require("copilot.setup").get_cred()
local util = require("copilot.util")
local M = {}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.getCompletions = true

M.start = function(params)
  vim.lsp.start_client({
    cmd = { require("copilot.util").get_copilot_path(params.plugin_manager_path) },
    cmd_env = {
      ["GITHUB_USER"] = user_data.user,
      ["GITHUB_TOKEN"] = user_data.token,
    },
    name = "copilot",
    trace = "messages",
    root_dir = vim.loop.cwd(),
    autostart = true,
    on_init = function(client, _)
      vim.lsp.buf_attach_client(0, client.id)
      if vim.fn.has("nvim-0.7") > 0 then
        vim.api.nvim_create_autocmd({ "BufEnter" }, {
          callback = function()
            util.attach_copilot()
          end,
          once = false,
        })
      else
        vim.cmd("au BufEnter * lua require('copilot.util').attach_copilot()")
      end
    end,
    on_attach = function()
      vim.schedule(function()
        params.on_attach()
      end)
    end,
  })
end

return M
