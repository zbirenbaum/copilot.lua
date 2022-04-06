local user_data = require("copilot.setup").get_cred()
local util = require("copilot.util")
local M = {}

local send_editor_info = function(a, b, c, d)
  local responses = vim.lsp.buf_request_sync(0, "setEditorInfo", {
    editorPluginInfo = {
      name = "copilot.vim",
      version = "1.1.0",
    },
    editorInfo = {
      version = "0.7.0-dev+1343-g4d3acd6be-dirty",
      name = "Neovim",
    },
  }, 600)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.getCompletions = true

M.start = function(params)
  vim.lsp.start_client({
    cmd = { require("copilot.util").get_copilot_path(params.plugin_manager_path) },
    cmd_env = {
      ["GITHUB_USER"] = user_data.user,
      ["GITHUB_TOKEN"] = user_data.token,
      ["COPILOT_AGENT_VERBOSE"] = 1,
    },
    handlers = {
      ["getCompletions"] = function()
        print("get completions")
      end,
      ["textDocumentSync"] = function()
        print("handle")
      end,
    },
    name = "copilot",
    trace = "messages",
    root_dir = vim.loop.cwd(),
    autostart = true,
    on_init = function(client, _)
      send_editor_info()
      vim.lsp.buf_attach_client(0, client.id)
      if vim.fn.has("nvim-0.7") then
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
