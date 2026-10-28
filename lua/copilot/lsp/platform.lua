local M = {}

--- Whether `sysname` (default: the current `uname` sysname) denotes Windows.
--- MinGW/MSYS2 builds of Neovim report e.g. `MINGW32_NT-10.0` or `MSYS_NT-10.0` instead of `Windows_NT`.
---@param sysname? string
---@return boolean
function M.is_windows(sysname)
  sysname = sysname or vim.uv.os_uname().sysname
  return sysname == "Windows_NT" or sysname:find("^MINGW") ~= nil or sysname:find("^MSYS") ~= nil
end

return M
