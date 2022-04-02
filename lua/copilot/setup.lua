local config_root = vim.fn.expand('~/.config') .. "/github-copilot/hosts.json"
local config_hosts = config_root .. "/hosts.json"
local request = require('plenary.curl').request
local post = require('plenary.curl').post

local M = {}

local function find_config_path()
   local config = vim.fn.expand('$XDG_CONFIG_HOME')
   if config then return config end
   config = vim.fn.has('win32') and vim.fn.expand('~/AppData/Local') or nil
   return config or vim.fn.expand('~/.config')
end


local function json_body(response)
   if response.headers['content-type'] == 'application/json' then
      return vim.fn.json_decode(response.body)
   end
end
local function oauth_user(token)
   local response = request({
      url = "https://api.github.com/user",
      headers = {
         Authorization = "Bearer " .. token,
      },
   })
   return json_body(response)
end

local function oauth_save(oauth_token)
   local user_data = oauth_user(oauth_token)
   local github = {oauth_token = oauth_token, user = user_data.login}
   return github
end

M.get_cred = function ()
   local userdata = vim.fn.json_decode(vim.api.nvim_eval("readfile('/home/zach/.config/github-copilot/hosts.json')"))
   local token = userdata["github.com"].oauth_token
   local user = oauth_user(token)
   return {user = user, token = token}
end

return M
