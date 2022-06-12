local util = require("copilot.util")

local panel = {
  n_results = 5,
  method = "getPanelCompletions",
  usecmp = false,
  buf = "",
  uri = "",
}

local completions = {}

panel.complete = vim.schedule_wrap(function (_, params, callback)
  local add_completion = function (result)
    local format = require("copilot_cmp.format").format_item
    if result then
      result.text = result.displayText
      local formatted = format(params, result)
      completions[formatted.label] = formatted
      vim.schedule(function() callback({
        isIncomplete = true,
        items = vim.tbl_values(completions)
      }) end)
    end
  end

  local completed = function ()
    vim.schedule(function()
      vim.schedule(function() callback({
        isIncomplete = false,
        items = vim.tbl_values(completions)
      }) end)
      completions = { isIncomplete = true, items = {} }
    end)
  end

  local completion_params = util.get_completion_params(panel.method)
  completion_params.panelId = panel.uri
  vim.lsp.buf_request(0, panel.method, completion_params, function () end)

  local handlers = require("copilot.handlers")

  vim.lsp.handlers["PanelSolution"] = vim.lsp.with(handlers["PanelSolution"], {
    callback = add_completion
  })
  vim.lsp.handlers["PanelSolutionDone"] = vim.lsp.with(handlers["PanelSolutionDone"], {
    completed
  })
  callback({ isIncomplete = true })

end)

function panel.create (opts)
  panel = vim.tbl_deep_extend("force", panel, opts or {})
  panel.buf = type(panel.uri) == "number" or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(panel.buf, "copilot:///" .. tostring(panel.buf))
  panel.uri = vim.uri_from_bufnr(panel.buf)
  return panel
end

return panel
