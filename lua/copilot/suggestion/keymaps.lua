local M = {}
local context = require("copilot.suggestion.context")
local config = require("copilot.config")
local suggestion = require("copilot.suggestion")
local preview = require("copilot.suggestion.preview")

function M.set_keymap(keymap)
  if keymap.accept then
    vim.keymap.set("i", keymap.accept, function()
      local ctx = context.get_ctx()
      -- If we trigger on accept but the suggestion has not been triggered yet, we let it go through so it does
      if (config.suggestion.trigger_on_accept and not ctx.first) or preview.is_visible() then
        suggestion.accept()
      else
        local termcode = vim.api.nvim_replace_termcodes(keymap.accept, true, false, true)
        vim.api.nvim_feedkeys(termcode, "n", true)
      end
    end, {
      desc = "[copilot] accept suggestion",
      silent = true,
    })
  end

  if keymap.accept_word then
    vim.keymap.set("i", keymap.accept_word, suggestion.accept_word, {
      desc = "[copilot] accept suggestion (word)",
      silent = true,
    })
  end

  if keymap.accept_line then
    vim.keymap.set("i", keymap.accept_line, suggestion.accept_line, {
      desc = "[copilot] accept suggestion (line)",
      silent = true,
    })
  end

  if keymap.next then
    vim.keymap.set("i", keymap.next, suggestion.next, {
      desc = "[copilot] next suggestion",
      silent = true,
    })
  end

  if keymap.prev then
    vim.keymap.set("i", keymap.prev, suggestion.prev, {
      desc = "[copilot] prev suggestion",
      silent = true,
    })
  end

  if keymap.dismiss then
    vim.keymap.set("i", keymap.dismiss, function()
      if preview.is_visible() then
        suggestion.dismiss()
        return "<Ignore>"
      else
        return keymap.dismiss
      end
    end, {
      desc = "[copilot] dismiss suggestion",
      expr = true,
      silent = true,
    })
  end
end

function M.unset_keymap(keymap)
  if keymap.accept then
    vim.keymap.del("i", keymap.accept)
  end

  if keymap.accept_word then
    vim.keymap.del("i", keymap.accept_word)
  end

  if keymap.accept_line then
    vim.keymap.del("i", keymap.accept_line)
  end

  if keymap.next then
    vim.keymap.del("i", keymap.next)
  end

  if keymap.prev then
    vim.keymap.del("i", keymap.prev)
  end

  if keymap.dismiss then
    vim.keymap.del("i", keymap.dismiss)
  end
end

return M
