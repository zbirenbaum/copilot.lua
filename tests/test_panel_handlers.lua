local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function()
      package.loaded["copilot.panel.handlers"] = nil
    end,
  },
})

T["panel_handlers()"] = MiniTest.new_set()

T["panel_handlers()"]["register and dispatch PanelSolution"] = function()
  local handlers = require("copilot.panel.handlers")
  local received = nil

  handlers.register_panel_handlers("panel-1", {
    on_solution = function(result)
      received = result
    end,
    on_solutions_done = function() end,
  })

  local data = { panelId = "panel-1", completionText = "hello", score = 0.9 }
  handlers.handlers.PanelSolution(nil, data)

  eq(received, data)
end

T["panel_handlers()"]["dispatch PanelSolutionsDone"] = function()
  local handlers = require("copilot.panel.handlers")
  local received = nil

  handlers.register_panel_handlers("panel-2", {
    on_solution = function() end,
    on_solutions_done = function(result)
      received = result
    end,
  })

  local data = { panelId = "panel-2", status = "OK" }
  handlers.handlers.PanelSolutionsDone(nil, data)

  eq(received, data)
end

T["panel_handlers()"]["unknown panelId does not dispatch"] = function()
  local handlers = require("copilot.panel.handlers")
  local called = false

  handlers.register_panel_handlers("panel-3", {
    on_solution = function()
      called = true
    end,
    on_solutions_done = function() end,
  })

  -- Dispatch with a different panelId
  handlers.handlers.PanelSolution(nil, { panelId = "unknown-panel" })

  eq(called, false)
end

T["panel_handlers()"]["unregister removes callbacks"] = function()
  local handlers = require("copilot.panel.handlers")
  local called = false

  handlers.register_panel_handlers("panel-4", {
    on_solution = function()
      called = true
    end,
    on_solutions_done = function() end,
  })

  handlers.unregister_panel_handlers("panel-4")

  handlers.handlers.PanelSolution(nil, { panelId = "panel-4" })
  eq(called, false)
end

T["panel_handlers()"]["dispatch to correct panelId among multiple"] = function()
  local handlers = require("copilot.panel.handlers")
  local received_a = nil
  local received_b = nil

  handlers.register_panel_handlers("panel-a", {
    on_solution = function(result)
      received_a = result
    end,
    on_solutions_done = function() end,
  })

  handlers.register_panel_handlers("panel-b", {
    on_solution = function(result)
      received_b = result
    end,
    on_solutions_done = function() end,
  })

  local data_b = { panelId = "panel-b", completionText = "world" }
  handlers.handlers.PanelSolution(nil, data_b)

  eq(received_a, nil)
  eq(received_b, data_b)
end

T["panel_handlers()"]["assert on invalid panelId type in register"] = function()
  local handlers = require("copilot.panel.handlers")

  local ok = pcall(handlers.register_panel_handlers, nil, {
    on_solution = function() end,
    on_solutions_done = function() end,
  })
  eq(ok, false)

  local ok2 = pcall(handlers.register_panel_handlers, 123, {
    on_solution = function() end,
    on_solutions_done = function() end,
  })
  eq(ok2, false)
end

T["panel_handlers()"]["assert on invalid panelId type in unregister"] = function()
  local handlers = require("copilot.panel.handlers")

  local ok = pcall(handlers.unregister_panel_handlers, nil)
  eq(ok, false)

  local ok2 = pcall(handlers.unregister_panel_handlers, 123)
  eq(ok2, false)
end

return T
