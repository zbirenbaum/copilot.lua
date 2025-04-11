local M = {
  callback = {
    PanelSolution = {},
    PanelSolutionsDone = {},
  },
  handlers = {},
}

---@alias copilot_panel_solution_data { panelId: string, completionText: string, displayText: string, range: { ['end']: { character: integer, line: integer }, start: { character: integer, line: integer } }, score: number, solutionId: string }
---@alias copilot_panel_on_solution_handler fun(result: copilot_panel_solution_data): nil
---@alias copilot_panel_solutions_done_data { panelId: string, status: 'OK'|'Error', message?: string }
---@alias copilot_panel_on_solutions_done_handler fun(result: copilot_panel_solutions_done_data): nil

M.handlers = {
  ---@param result copilot_panel_solution_data
  PanelSolution = function(_, result)
    if M.callback.PanelSolution[result.panelId] then
      M.callback.PanelSolution[result.panelId](result)
    end
  end,

  ---@param result copilot_panel_solutions_done_data
  PanelSolutionsDone = function(_, result)
    if M.callback.PanelSolutionsDone[result.panelId] then
      M.callback.PanelSolutionsDone[result.panelId](result)
    end
  end,
}

---@param panelId string
---@param handlers { on_solution: copilot_panel_on_solution_handler, on_solutions_done: copilot_panel_on_solutions_done_handler }
function M.register_panel_handlers(panelId, handlers)
  assert(type(panelId) == "string", "missing panelId")
  M.callback.PanelSolution[panelId] = handlers.on_solution
  M.callback.PanelSolutionsDone[panelId] = handlers.on_solutions_done
end

---@param panelId string
function M.unregister_panel_handlers(panelId)
  assert(type(panelId) == "string", "missing panelId")
  M.callback.PanelSolution[panelId] = nil
  M.callback.PanelSolutionsDone[panelId] = nil
end

return M
