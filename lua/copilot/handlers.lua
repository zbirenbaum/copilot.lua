local oldprint = print
local print = function (x) oldprint(vim.inspect(x)) end

local lsp_handlers = {
  ["PanelSolution"] = function (_, result, _, config)
    config.callback(result)
  end,

  ["PanelSolutionsDone"] = function (err, result, ctx, config)
    config.callback()
  end
}

return lsp_handlers
