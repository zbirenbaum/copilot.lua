local lsp_handlers = {
  callbacks = {
    ["PanelSolution"] = {},
    ["PanelSolutionsDone"] = {}
  },
}

local handlers = {
  ["PanelSolution"] = function (_, result, _, config)
    if not result then return "err" end
    if result.panelId and config.callbacks[result.panelId] then
      config.callbacks[result.panelId](result)
    elseif not config.callbacks[result.panelId] and result.panelId then
      return
    else
      for _, callback in pairs(config.callbacks) do callback() end
    end
  end,

  ["PanelSolutionsDone"] = function (_, _, _, config)
    for _, callback in pairs(config.callbacks) do
      callback()
    end
  end
}

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

lsp_handlers.remove_all_name = function (fn_name)
  for handler, _ in pairs(lsp_handlers.callbacks) do
    lsp_handlers.remove_handler_callback(handler, fn_name)
  end
end

return lsp_handlers
