---@class ServerConfig
---@field type string<'nodejs', 'binary'> Type of the server
---@field custom_server_filepath string|nil Path to the custom server file

local server = {
  ---@type ServerConfig
  default = {
    type = "nodejs",
    custom_server_filepath = nil,
  },
}

return server
