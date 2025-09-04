local logger = require("copilot.logger")
local M = {}

M.messages = {}
M.completion_responses = {
  ["numbers_with_spaces.txt"] = {
    completions = {
      {
        displayText = "8 9",
        docVersion = 7,
        position = {
          character = 2,
          line = 2,
        },
        range = {
          ["end"] = {
            character = 2,
            line = 2,
          },
          start = {
            character = 0,
            line = 2,
          },
        },
        text = "7 8 9",
        uuid = "b7493391-cd5e-4c10-b0a6-2a844533fbed",
      },
    },
  },
  ["numbers_as_arrays.txt"] = {
    completions = {
      {
        displayText = "  19,20,21\n  22,23,24\n  25,26,27\n}\n{\n  28,29,30\n  31,32,33\n  34,35,36\n}\n{\n  37,38,39\n  40,41,42\n  43,44,45\n}\n{\n  46,47,48\n  49,50,51\n  52,53,54\n}",
        docVersion = 30,
        position = {
          character = 0,
          line = 11,
        },
        range = {
          ["end"] = {
            character = 0,
            line = 11,
          },
          start = {
            character = 0,
            line = 11,
          },
        },
        text = "  19,20,21\n  22,23,24\n  25,26,27\n}\n{\n  28,29,30\n  31,32,33\n  34,35,36\n}\n{\n  37,38,39\n  40,41,42\n  43,44,45\n}\n{\n  46,47,48\n  49,50,51\n  52,53,54\n}",
        uuid = "1df58ae9-3e93-4e6a-b514-218a9fe7e816",
      },
    },
  },
}

---@param text_document lsp.VersionedTextDocumentIdentifier
local function get_lsp_responses(text_document)
  local filename = vim.fs.basename(vim.uri_to_fname(text_document.uri))
  logger.trace("get_lsp_responses: " .. filename)

  return M.completion_responses[filename]
    or {
      ---@type copilot_get_completions_data
      completions = {
        {
          displayText = "89",
          docVersion = 7,
          position = {
            character = 1,
            line = 2,
          },
          range = {
            ["end"] = {
              character = 1,
              line = 2,
            },
            start = {
              character = 0,
              line = 2,
            },
          },
          text = "789",
          uuid = "63f4ab66-e550-4313-9023-144a33254607",
        },
      },
    }
end

function M.server()
  local closing = false
  local srv = {}
  -- local seen_files = {}

  function srv.request(method, params, handler)
    logger.trace("lsp request: " .. method)
    table.insert(M.messages, { method = method, params = params })
    if method == "initialize" then
      handler(nil, {
        capabilities = {},
      })
    elseif method == "shutdown" then
      handler(nil, nil)
    elseif method == "getCompletions" then
      -- elseif method == "textDocument/copilotInlineEdit" then
      -- if not seen_files[params.textDocument.uri] then
      -- seen_files[params.textDocument.uri] = true
      local response = get_lsp_responses(params.textDocument)
      vim.defer_fn(function()
        handler(nil, response)
      end, 10)
    -- local empty_response = {
    --   edits = {},
    -- }
    -- handler(nil, empty_response)
    elseif method == "checkStatus" then
      vim.defer_fn(function()
        handler(nil, { user = "someUser", status = "OK" })
        local handlers = require("copilot.status").handlers
        handlers.statusNotification(
          nil,
          { busy = false, kind = "Normal", message = "", status = "Normal" },
          { client_id = 1, method = "statusNotification" }
        )
      end, 10)
    elseif method == "notifyAccepted" or method == "notifyRejected" or method == "notifyShown" then
      handler(nil, {})
    elseif method == "getPanelCompletions" then
      local params_panel = params or {}
      local panelId = params_panel.panelId or (params_panel.doc and params_panel.doc.panelId) or "test-panel-id"

      vim.defer_fn(function()
        handler(nil, {
          solutionCountTarget = 10,
        })
        local handlers = require("copilot.panel.handlers")

        handlers.handlers.PanelSolution(nil, {
          completionText = "89\n0\n1",
          displayText = "789\n0\n1",
          panelId = panelId,
          range = {
            ["end"] = {
              character = 1,
              line = 2,
            },
            start = {
              character = 1,
              line = 2,
            },
          },
          score = 0,
          solutionId = "213fc33d8f2dbde3207734e3097ea72a69fb8b009f2878468cdd9e74b70a1e59",
        })

        handlers.handlers.PanelSolutionsDone(nil, {
          panelId = panelId,
          status = "OK",
        })
      end, 10)
    else
      assert(false, "Unhandled method: " .. method)
    end
  end

  function srv.notify(method, params)
    logger.trace("lsp notify")
    table.insert(M.messages, { method = method, params = params })
    if method == "exit" then
      closing = true
    end
  end

  function srv.is_closing()
    logger.trace("lsp closing")
    return closing
  end

  function srv.terminate()
    logger.trace("lsp terminate")
    closing = true
  end

  return srv
end

function M.reset()
  M.messages = {}
end

return M
