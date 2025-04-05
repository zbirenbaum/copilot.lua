-- local eq = MiniTest.expect.equality
-- local neq = MiniTest.expect.no_equality
local reference_screenshot = MiniTest.expect.reference_screenshot
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
      -- child.lua([[require("osv").launch({ port = 8086 })]])
    end,
    post_once = child.stop,
  },
})

T["suggestion()"] = MiniTest.new_set()

-- TODO: Need means of watching for the suggestion to popup and not randomly wait x ms
-- Should be able to use the screenshot to parsse for the suggesetion, u.get_lines does not work
-- Also, this test can fail if the LSP is taking more time than usual and re-running it passes
T["suggestion()"]["suggestion works"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[M.setup({
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
  vim.loop.sleep(3000)
  child.lua("vim.wait(0)")

  reference_screenshot(child.get_screenshot())
end

return T
