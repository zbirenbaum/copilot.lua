local eq = MiniTest.expect.equality
local child_helper = require("tests.child_helper")
local child = child_helper.new_child_neovim("test_nes")

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      child.run_pre_case(true)
    end,
    post_once = child.stop,
  },
})

T["nes()"] = MiniTest.new_set()

T["nes()"]["setup does nothing when nes is disabled"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local config = require("copilot.config")
    config.nes.enabled = false
    local nes = require("copilot.nes")
    nes.initialized = false
    nes.setup({})
    return nes.initialized
  ]])
  eq(result, false)
end

T["nes()"]["set_keymap does nothing when nes is disabled"] = function()
  child.configure_copilot()
  child.lua([[
    local config = require("copilot.config")
    config.nes.enabled = false
    local nes = require("copilot.nes")
    nes.set_keymap(vim.api.nvim_get_current_buf())
  ]])
end

T["nes()"]["unset_keymap does nothing when nes is disabled"] = function()
  child.configure_copilot()
  child.lua([[
    local config = require("copilot.config")
    config.nes.enabled = false
    local nes = require("copilot.nes")
    nes.unset_keymap(vim.api.nvim_get_current_buf())
  ]])
end

T["nes()"]["teardown does nothing when not initialized"] = function()
  child.configure_copilot()
  child.lua([[
    local nes = require("copilot.nes")
    nes.initialized = false
    nes.teardown()
  ]])
end

T["nes()"]["setup catches copilot-lsp errors gracefully"] = function()
  child.configure_copilot()
  local result = child.lua([[
    local config = require("copilot.config")
    config.nes.enabled = true
    -- Mock nes_api to throw an error
    package.loaded["copilot.nes.api"] = {
      nes_lsp_on_init = function()
        error("copilot-lsp not found")
      end,
    }
    -- Reload nes module to pick up mocked api
    package.loaded["copilot.nes"] = nil
    local nes = require("copilot.nes")
    local ok = pcall(nes.setup, {})
    return ok
  ]])
  eq(result, true)
end

return T
