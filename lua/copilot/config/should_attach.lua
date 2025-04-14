---@alias ShouldAttachFunc fun(bufnr: integer, bufname: string): boolean

local logger = require("copilot.logger")

local should_attach = {
  ---@type ShouldAttachFunc
  default = function(_, _)
    if not vim.bo.buflisted then
      logger.debug("not attaching, bugger is not 'buflisted'")
      return false
    end

    if vim.bo.buftype ~= "" then
      logger.debug("not attaching, buffer 'buftype' is " .. vim.bo.buftype)
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
