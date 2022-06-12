local lsp_handlers = {
  callbacks = {
    ["PanelSolution"] = {},
    ["PanelSolutionsDone"] = {}
  },
}

local handlers = {
  ["PanelSolution"] = function (_, result, _, config)
    for _, callback in pairs(config.callbacks) do
      callback(result)
    end
  end,
  ["PanelSolutionsDone"] = function (_, _, _, config)
    for _, callback in pairs(config.callbacks) do
      callback()
    end
  end
}

-- require name so not confusing
lsp_handlers.add_handler_callback = function (handler, fn_name, fn)
  lsp_handlers.callbacks[handler][fn_name] = fn
  vim.lsp.handlers[handler] = vim.lsp.with(handlers[handler], {
    callbacks = lsp_handlers.callbacks[handler]
  })
end

lsp_handlers.remove_handler_callback = function (handler, fn_name)
  lsp_handlers.callbacks[handler][fn_name] = nil
  vim.lsp.handlers[handler] = vim.lsp.with(handlers[handler], {
    callbacks = lsp_handlers.callbacks[handler]
  })
end

return lsp_handlers
