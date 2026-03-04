---@alias ShouldAttachFunc fun(bufnr: integer, bufname: string): boolean

local logger = require("copilot.logger")

local should_attach = {
  ---@type ShouldAttachFunc
  default = function(buf_id, _)
    if not vim.bo[buf_id].buflisted then
      logger.debug("not attaching, buffer is not 'buflisted'")
      return false
    end

    if vim.bo[buf_id].buftype ~= "" then
      logger.debug("not attaching, buffer 'buftype' is " .. vim.bo[buf_id].buftype)
      return false
    end

    return true
  end,
}

---@param config ShouldAttachFunc
function should_attach.validate(config)
  vim.validate("should_attach", config, "function")
end

return should_attach
