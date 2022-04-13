local M = {}

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
