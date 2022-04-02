local M = {}

local format_pos = function()
   local pos = vim.api.nvim_win_get_cursor(0)
   return { character = pos[2], line = pos[1]-1 }
end

local get_relfile = function()
   local file,_= string.gsub(vim.api.nvim_buf_get_name(0), vim.loop.cwd() .. "/", '')
   return file
end

M.get_completion_params = function()
   local params = {
      options = vim.empty_dict(),
      doc = {
         relativePath = get_relfile(),
         source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'),
         languageId = vim.bo.filetype,
         insertSpaces = true,
         tabsize = vim.bo.shiftwidth,
         indentsize = vim.bo.shiftwidth,
         position = format_pos(),
         path = vim.api.nvim_buf_get_name(0),
      },
   }
   return params
end

M.get_copilot_path = function()
   local root_path = vim.fn.stdpath("data") .. "/site/pack/packer/"
   for _, loc in ipairs{"opt", "start"} do
      local copilot_path = root_path .. loc .. "/copilot.lua/copilot/index.js"
      if vim.fn.filereadable(copilot_path) then
         return copilot_path
      end
   end
end

return M
