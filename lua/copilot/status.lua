local status = {
  client_id = 0,
  data = {
    status = "",
    message = "",
  },
}

status.handlers = {
  ---@param result { status: string, message: string }
  ---@param ctx { client_id: integer, method: string }
  statusNotification = function(_, result, ctx)
    status.client_id = ctx.client_id
    status.data = result
  end,
}

function status.get()
  return status.data
end

return status
