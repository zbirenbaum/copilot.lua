local M = {}

function M.launch_lua_debugee(child)
  -- child.lua([[local dap = require("nvim-dap")
  --   dap.configurations.lua = {
  --     {
  --       type = 'nlua',
  --       request = 'attach',
  --       name = "Attach to running Neovim instance",
  --     }
  --   }
  --
  --   dap.adapters.nlua = function(callback, config)
  --     callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
  --   end
  -- ]])
  child.lua([[require("osv").launch({ port = 8086 })]])
end

function M.attach_to_debugee()
  require("dap").continue()
end

return M
