---@class (exact) ServerConfig
---@field type string<'nodejs', 'binary'> Type of the server
---@field custom_server_filepath? string|nil Path to the custom server file, can be absolute, relative or a file name (for PATH)

local server = {
  ---@type ServerConfig
  default = {
    type = "nodejs",
    custom_server_filepath = nil,
  },
}

-- TODO: add support for relative paths
---@param config ServerConfig
function server.validate(config)
  vim.validate("type", config.type, function(server_type)
    return type(server_type) == "string" and (server_type == "nodejs" or server_type == "binary")
  end, false, "nodejs or binary")
  vim.validate("custom_server_filepath", config.custom_server_filepath, { "string", "nil" })

  if config.custom_server_filepath then
    config.custom_server_filepath = vim.fs.normalize(config.custom_server_filepath)
  end
end

return server
