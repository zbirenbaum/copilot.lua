local eq = MiniTest.expect.equality
-- local neq = MiniTest.expect.no_equality
-- local reference_screenshot = MiniTest.expect.reference_screenshot
local child = MiniTest.new_child_neovim()
-- local u = require("tests.utils")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      if vim.fn.filereadable("./tests/logs/test_suggestion.log") == 1 then
        vim.fn.delete("./tests/logs/test_suggestion.log")
      end
    end,
    pre_case = function()
      child.restart({ "-u", "tests/scripts/minimal_init.lua" })
      child.bo.readonly = false
      child.lua("M = require('copilot')")
      child.lua("cmd = require('copilot.command')")
      child.lua("p = require('copilot.panel')")
      -- child.lua([[require("osv").launch({ port = 8086 })]])
    end,
    post_once = child.stop,
  },
})

T["panel()"] = MiniTest.new_set()

-- This test can fail if the LSP is taking more time than usual and re-running it passes
T["panel()"]["panel suggestions works"] = function()
  child.o.lines, child.o.columns = 30, 100
  child.lua([[M.setup({
    panel = {
      auto_refresh = true,
    },
    suggestion = {
      auto_trigger = true,
    },
    logger = {
      file_log_level = vim.log.levels.TRACE,
      file = "./tests/logs/test_suggestion.log",
    },
    filetypes = {
      ["*"] = true,
    },
  })]])

  -- look for a synchronous way to wait for engine to be up
  vim.loop.sleep(500)
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7")
  child.lua("p.toggle()")

  local i = 0
  local lines = ""
  while i < 50 do
    vim.loop.sleep(200)
    child.lua("vim.wait(0)")
    lines = child.api.nvim_buf_get_lines(2, 4, 5, false)
    if lines[1] == "789" then
      break
    end
    i = i + 1
  end

  eq(lines[1], "789")
end

return T
