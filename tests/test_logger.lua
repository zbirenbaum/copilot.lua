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

for _, case in ipairs({
  { name = "string messages", msg = "Document URI not found", expected = "Document URI not found" },
  {
    name = "RPC error messages",
    msg = { code = -32603, message = "Document URI not found" },
    expected = "Document URI not found",
  },
  { name = "tables without messages", msg = { code = -32603 }, expected = "{\n  code = -32603\n}" },
  {
    name = "tables with non-string messages",
    msg = { message = { reason = "missing document" } },
    expected = '{\n  message = {\n    reason = "missing document"\n  }\n}',
  },
  { name = "empty tables", msg = {}, expected = "{}" },
}) do
  T["logger()"]["formats " .. case.name .. " in notifications and files"] = function()
    local result = child.lua(
      [[
      local msg = ...
      local logger = require("copilot.logger")
      local path = vim.fn.tempname()
      logger.setup({
        file = path,
        file_log_level = vim.log.levels.ERROR,
        print_log_level = vim.log.levels.ERROR,
      })
      local notification
      vim.notify = function(text, level)
        notification = { text = text, level = level }
      end
      logger.error(msg, { retry = false })
      local contents
      local completed = vim.wait(1000, function()
        if vim.fn.filereadable(path) == 1 then
          contents = table.concat(vim.fn.readfile(path), "\n")
        end
        return notification ~= nil and contents ~= nil and contents ~= ""
      end, 10)
      vim.fn.delete(path)
      assert(completed, "log outputs did not complete")
      return { notification = notification, file_message = contents:match("%[ERROR%]: (.*)") }
    ]],
      { case.msg }
    )
    local expected = case.expected .. "\n{\n  retry = false\n}"
    eq(result.notification, { text = "[Copilot.lua] " .. expected, level = vim.log.levels.ERROR })
    eq(result.file_message, expected)
  end
end

T["logger()"]["notify formats RPC errors when log output is disabled"] = function()
  local result = child.lua([[
    local logger = require("copilot.logger")
    logger.file_log_level = vim.log.levels.OFF
    logger.print_log_level = vim.log.levels.OFF
    local notification
    vim.notify = function(msg, level)
      notification = { text = msg, level = level }
    end
    logger.notify({ code = -32603, message = "Document URI not found" })
    assert(vim.wait(1000, function() return notification ~= nil end, 10))
    return notification
  ]])
  eq(result, { text = "[Copilot.lua] Document URI not found", level = vim.log.levels.INFO })
end

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
