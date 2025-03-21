local completion_store = {
  [""] = { "auth", "attach", "detach", "disable", "enable", "panel", "status", "suggestion", "toggle", "version" },
  auth = { "signin", "signout" },
  panel = { "accept", "jump_next", "jump_prev", "open", "refresh" },
  suggestion = { "accept", "accept_line", "accept_word", "dismiss", "next", "prev", "toggle_auto_trigger" },
  workspace = { "add" },
}

vim.api.nvim_create_user_command("Copilot", function(opts)
  local params = vim.split(opts.args, "%s+", { trimempty = true })

  local mod_name, action_name = params[1], params[2]
  if not mod_name then
    mod_name = "status"
  end

  local ok, mod = pcall(require, "copilot." .. mod_name)
  if not ok then
    action_name = mod_name
    mod_name = "command"
    mod = require("copilot.command")
  end

  if not action_name then
    if mod_name == "auth" then
      action_name = "signin"
    elseif mod_name == "panel" then
      action_name = "open"
    elseif mod_name == "suggestion" then
      action_name = "toggle_auto_trigger"
    end
  end

  if not mod[action_name] then
    print("[Copilot] Unknown params: " .. opts.args)
    return
  end

  if mod_name == "command" then
    mod[action_name]({
      force = opts.bang,
    })
    return
  end

  local remaining_args = ""
  if #params > 2 then
    remaining_args = table.concat(params, " ", 3)
  end

  require("copilot.client").use_client(function()
    mod[action_name]({
      force = opts.bang,
      args = remaining_args,
    })
  end)
end, {
  bang = true,
  nargs = "?",
  complete = function(_, cmd_line)
    local has_space = string.match(cmd_line, "%s$")
    local params = vim.split(cmd_line, "%s+", { trimempty = true })

    if #params == 1 then
      return completion_store[""]
    elseif #params == 2 and not has_space then
      return vim.tbl_filter(function(cmd)
        return not not string.find(cmd, "^" .. params[2])
      end, completion_store[""])
    end

    if #params >= 2 and completion_store[params[2]] then
      if #params == 2 then
        return completion_store[params[2]]
      elseif #params == 3 and not has_space then
        return vim.tbl_filter(function(cmd)
          return not not string.find(cmd, "^" .. params[3])
        end, completion_store[params[2]])
      end
    end
  end,
})
