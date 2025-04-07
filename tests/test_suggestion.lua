local reference_screenshot = MiniTest.expect.reference_screenshot
local child = MiniTest.new_child_neovim()
-- local env = require("tests.env")

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
      -- child.fn.setenv("GITHUB_COPILOT_TOKEN", env.COPILOT_TOKEN)
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

T["suggestion()"]["auto_trigger is false, will not show ghost test"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[M.setup({
    suggestion = {
      auto_trigger = false,
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

T["suggestion()"]["accept keymap to trigger sugestion"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[M.setup({
    suggestion = {
      auto_trigger = false,
      keymap = {
        accept = "<Tab>",
      },
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
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")
  vim.loop.sleep(3000)
  child.lua("vim.wait(0)")

  reference_screenshot(child.get_screenshot())
end

T["suggestion()"]["accept keymap, no suggestion, execute normal keystroke"] = function()
  child.o.lines, child.o.columns = 10, 15
  child.lua([[M.setup({
    suggestion = {
      auto_trigger = false,
      trigger_on_accept = false,
      keymap = {
        accept = "<Tab>",
      },
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
  child.type_keys("i123", "<Esc>", "o456", "<Esc>", "o7", "<Tab>")
  vim.loop.sleep(3000)
  child.lua("vim.wait(0)")

  reference_screenshot(child.get_screenshot())
end

return T
