local env = require("tests.env")
local M = {}

if not _G.attach_debugger then
  _G.attach_debugger = false
end

---@param test_name string
function M.new_child_neovim(test_name)
  ---@class MiniTest.child
  local child = MiniTest.new_child_neovim()
  local logfile = string.format("./tests/logs/%s.log", test_name)
  child.config = nil

  if vim.fn.filereadable(logfile) == 1 then
    vim.fn.delete(logfile)
  end

  function child.reset_config()
    child.config = {
      panel = "",
      suggestion = [[
        suggestion_notification = function(virt_text, _)
          if (#virt_text > 0) and (#virt_text[1] > 0) then
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
      require("osv").launch({ port = 8086, blocking = true })
    ]])
  end

  function child.run_pre_case()
    child.reset_config()
    child.restart({ "-u", "tests/scripts/minimal_init.lua" })
    if env.COPILOT_TOKEN and env.COPILOT_TOKEN ~= "" then
      child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
    end
    child.setup_and_wait_for_debugger()
    child.lua("M = require('copilot')")
  end

  function child.configure_copilot()
    local script = ""
    for k, v in pairs(child.config) do
      if v ~= "" and v ~= nil then
        if type(v) == "string" then
          if v:sub(1, 8) == "function" then
            script = string.format(
              [[%s
%s = %s,]],
              script,
              k,
              v
            )
          else
            script = string.format(
              [[%s
%s = { %s },]],
              script,
              k,
              v
            )
          end
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

    -- write to temporary file for debugging purposes
    local tmpfile = string.format("./tests/logs/test_config.txt")
    local file = io.open(tmpfile, "w")
    if file then
      file:write(script)
      file:close()
    else
      error("Could not open temporary file for writing: " .. tmpfile)
    end

    child.lua(script)

    child.lua([[
      local copilot_is_initialized = function()
        local client = require("copilot.client")
        return client.initialized
      end

      vim.wait(5000, copilot_is_initialized, 10)
    ]])
  end

  function child.wait_for_suggestion()
    child.lua([[
      vim.wait(5000, function()
        return M.suggested
      end, 10)
    ]])
  end

  function child.wait_for_panel_suggestion()
    child.lua([[
      local function suggestion_is_visible()
        lines = vim.api.nvim_buf_get_lines(2, 4, 5, false)
        return lines[1] and lines[1] ~= "" 
      end

      vim.wait(5000, function()
        return suggestion_is_visible()
      end, 50)
    ]])
  end

  return child
end

return M
