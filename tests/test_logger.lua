local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_logger")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(false)
    end,
    post_once = child.stop,
  },
})

T["logger()"] = MiniTest.new_set()

T["logger()"]["setup configures log file and levels"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    logger.setup({
      file = "/tmp/test-copilot.log",
      file_log_level = vim.log.levels.DEBUG,
      print_log_level = vim.log.levels.ERROR,
    })
    return {
      file = logger.log_file,
      file_level = logger.file_log_level,
      print_level = logger.print_log_level,
    }
  ]])
  eq(result.file, "/tmp/test-copilot.log")
  eq(result.file_level, 1) -- DEBUG
  eq(result.print_level, 4) -- ERROR
end

T["logger()"]["log level OFF suppresses all output"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    logger.file_log_level = vim.log.levels.OFF
    logger.print_log_level = vim.log.levels.OFF
    local notify_called = false
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      notify_called = true
      orig_notify(msg, level)
    end
    logger.error("test error")
    vim.notify = orig_notify
    return notify_called
  ]])
  eq(result, false)
end

T["logger()"]["handle_lsp_trace does not error on nil result"] = function()
  child.lua([[
    local logger = require("copilot.logger")
    logger.handle_lsp_trace(nil, nil, nil)
  ]])
end

T["logger()"]["handle_lsp_progress does not error on nil result"] = function()
  child.lua([[
    local logger = require("copilot.logger")
    logger.handle_lsp_progress(nil, nil, nil)
  ]])
end

T["logger()"]["handle_log_lsp_messages does not error on nil result"] = function()
  child.lua([[
    local logger = require("copilot.logger")
    logger.handle_log_lsp_messages(nil, nil, nil)
  ]])
end

T["logger()"]["handle_log_lsp_messages maps type 2 to warn level"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    local captured_level = nil
    local orig_log = logger.log
    logger.log = function(level, msg, ...)
      captured_level = level
    end
    logger.handle_log_lsp_messages(nil, { type = 2, message = "test warning" }, nil)
    logger.log = orig_log
    return captured_level
  ]])
  eq(result, 3) -- WARN
end

T["logger()"]["handle_log_lsp_messages maps type 1 to error level"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    local captured_level = nil
    local orig_log = logger.log
    logger.log = function(level, msg, ...)
      captured_level = level
    end
    logger.handle_log_lsp_messages(nil, { type = 1, message = "test error" }, nil)
    logger.log = orig_log
    return captured_level
  ]])
  eq(result, 4) -- ERROR
end

T["logger()"]["handle_log_lsp_messages forces abort errors to trace"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    local captured_level = nil
    local orig_log = logger.log
    logger.log = function(level, msg, ...)
      captured_level = level
    end
    logger.handle_log_lsp_messages(nil, {
      type = 1,
      message = "Request textDocument/copilotInlineEdit: AbortError: The operation was aborted"
    }, nil)
    logger.log = orig_log
    return captured_level
  ]])
  eq(result, 0) -- TRACE (forced down from ERROR)
end

return T
