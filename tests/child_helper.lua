local env = require("tests.env")
local M = {}
_G.attach_debugger = false

---@param test_name string
function M.new_child_neovim(test_name)
  ---@class MiniTest.child
  local child = MiniTest.new_child_neovim()
  local logfile = string.format("./tests/logs/%s.log", test_name)

  -- TODO: this needs a reset, as it is reused in multiple tests
  -- TODO: this does not work, as the child needs a string representation of the config
  child.config = nil

  if vim.fn.filereadable(logfile) == 1 then
    vim.fn.delete(logfile)
  end

  function child.reset_config()
    child.config = {
      panel = "",
      suggestion = [[
        suggestion_notification = function(virt_text, _)
          if (#virt_text > 0) and (#virt_text[1] > 0) and (virt_text[1][1] == "89") then
            M.suggested = true
          end
        end,
      ]],
      logger = string.format(
        [[
        file_log_level = vim.log.levels.TRACE,
        file = "%s",
      ]],
        logfile
      ),
      server = "",
      root_dir = "",
      should_attach = "",
      filetypes = [[
        ["*"] = true,
      ]],
      auth_provider_url = "",
      workspace_folders = "",
      server_opts_overrides = "",
      copilot_model = "",
      copilot_node_command = "",
    }
  end

  function child.setup_and_wait_for_debugger()
    if not _G.attach_debugger then
      return
    end

    child.lua([[
      local osv = require("osv")
      local debugger_attached = false
      osv.on_attach = function() debugger_attached = true end
      osv.launch({ port = 8086 })
      -- wait until a debuggee is attached, or 30 seconds
      vim.wait(30000, function() return debugger_attached end, 10)
    ]])
  end

  function child.run_pre_case()
    child.reset_config()
    child.restart({ "-u", "tests/scripts/minimal_init.lua" })
    child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
    child.setup_and_wait_for_debugger()
  end

  function child.configure_copilot()
    local script = ""
    for k, v in pairs(child.config) do
      if v ~= "" and v ~= nil then
        if type(v) == "string" then
          script = string.format(
            [[%s%s = {
          %s
          },
          ]],
            script,
            k,
            v
          )
        end
      end
    end

    script = string.format(
      [[
        M.suggested = false
        M.setup({ %s })
      ]],
      script
    )

    child.lua(script)

    child.lua([[
      local copilot_is_initialized = function()
        local client = require("copilot.client")
        return client.initialized
      end

      vim.wait(30000, copilot_is_initialized, 10)
    ]])
  end

  function child.wait_for_suggestion()
    child.lua([[
      vim.wait(30000, function()
        return M.suggested
      end, 10)
    ]])
  end

  return child
end

return M
