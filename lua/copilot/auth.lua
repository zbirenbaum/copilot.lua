local util = require("copilot.util")

local M = {}

function M.setup(client)
  local function echo(message)
    vim.cmd('echom "[Copilot] ' .. message .. '"')
  end

  local function copy_to_clipboard(str)
    vim.cmd(string.format(
      [[
        let @+ = "%s"
        let @* = "%s"
      ]],
      str,
      str
    ))
  end

  local request = function(method, params)
    local co = coroutine.running()
    params.id = util.get_next_id()
    client.rpc.request(method, params, function(err, data)
      coroutine.resume(co, err, data)
    end)
    local err, data = coroutine.yield()
    if err then
      echo("Error: " .. err)
      error(err)
    end
    return data
  end

  local function open_signin_popup(code, url)
    local lines = {
      " [Copilot] ",
      "",
      " First copy your one-time code: ",
      "   " .. code .. " ",
      " In your browser, visit: ",
      "   " .. url .. " ",
      "",
      " ...waiting, it might take a while and ",
      " this popup will auto close once done... ",
    }
    local height, width = #lines, math.max(unpack(vim.tbl_map(function(line)
      return #line
    end, lines)))

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local winid = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      style = "minimal",
      border = "single",
      row = (vim.o.lines - height) / 2,
      col = (vim.o.columns - width) / 2,
      height = height,
      width = width,
    })
    vim.api.nvim_win_set_option(winid, "winhighlight", "Normal:Normal")

    return function()
      vim.api.nvim_win_close(winid, true)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  local initiate_setup = coroutine.wrap(function()
    local data = request("checkStatus", {})

    if data.user then
      echo("Authenticated as GitHub user: " .. data.user)
      return
    end

    local signin = request("signInInitiate", {})

    if not signin.verificationUri then
      echo("Failed to setup")
      return
    end

    copy_to_clipboard(signin.userCode)

    local close_signin_popup = open_signin_popup(signin.userCode, signin.verificationUri)

    local confirm = request("signInConfirm", { userCode = signin.userCode })

    close_signin_popup()

    if string.lower(confirm.status) ~= "ok" then
      echo("Authentication failure: " .. confirm.error.message)
      return
    end

    echo("Authenticated as GitHub user: " .. confirm.user)
  end)

  initiate_setup()
end

local function find_config_path()
  local config = vim.fn.expand("$XDG_CONFIG_HOME")
  if config and vim.fn.isdirectory(config) > 0 then
    return config
  elseif vim.fn.has("win32") > 0 then
    config = vim.fn.expand("~/AppData/Local")
    if vim.fn.isdirectory(config) > 0 then
      return config
    end
  else
    config = vim.fn.expand("~/.config")
    if vim.fn.isdirectory(config) > 0 then
      return config
    else
      print("Error: could not find config path")
    end
  end
end

local function json_body(response)
  if response.headers["content-type"] == "application/json" then
    return vim.json.decode(response.body)
  end
end

local function oauth_user(token)
  return vim.fn.system('curl -s --header "Authorization: Bearer ' .. token .. '" https://api.github.com/user')
end

local function oauth_save(oauth_token)
  local user_data = oauth_user(oauth_token)
  local github = { oauth_token = oauth_token, user = user_data.login }
  return github
end

M.get_cred = function()
  local userdata = vim.json.decode(
    vim.api.nvim_eval("readfile('" .. find_config_path() .. "/github-copilot/hosts.json')")[1]
  )
  local token = userdata["github.com"].oauth_token
  local user = oauth_user(token)
  return { user = user, token = token }
end

return M
