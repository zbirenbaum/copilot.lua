local util = require("copilot.util")
local logger = require("copilot.logger")

local M = {
  ---@class copilot_server_info
  ---@field path string
  ---@field filename string
  ---@field absolute_path string
  ---@field absolute_filepath string
  ---@field extracted_filename string
  copilot_server_info = nil,
  initialized = false,
  initialization_failed = false,
}

local function ensure_directory_exists(path)
  if path and vim.fn.isdirectory(path) == 0 then
    if vim.fn.mkdir(path) == 0 then
      logger.error("failed to create directory: " .. path)
      return false
    end
  end

  return true
end

---@param folder string
---@param except_file string
local function delete_all_except(folder, except_file)
  for file in vim.fs.dir(folder) do
    if file ~= except_file then
      local file_path = folder .. "/" .. file
      if vim.fn.isdirectory(file_path) == 1 then
        vim.fn.delete(file_path, "rf")
      else
        vim.fn.delete(file_path)
      end
    end
  end
end

---@param url string
---@param local_server_zip_filepath string
---@param local_server_zip_path string
---@return boolean
local function download_file(url, local_server_zip_filepath, local_server_zip_path)
  logger.notify("current version of copilot-language-server is not downloaded, downloading")

  if vim.fn.executable("curl") ~= 1 then
    vim.api.nvim_err_writeln("Error: curl is not available")
    M.initialization_failed = true
    return false
  end

  if vim.fn.filereadable(local_server_zip_filepath) == 1 then
    vim.fn.delete(local_server_zip_filepath)
  else
    logger.trace("copilot-language-server zip file not found, ensuring directory exists")

    if not ensure_directory_exists(local_server_zip_path) then
      return false
    end
  end

  local cookie_file = vim.fs.joinpath(local_server_zip_path, "cookies.txt")
  local cmd = string.format(
    'curl -s -L -c "%s" -b "%s" -o "%s" "%s"',
    cookie_file:gsub("\\", "\\\\"),
    cookie_file:gsub("\\", "\\\\"),
    local_server_zip_filepath:gsub("\\", "\\\\"),
    url
  )

  logger.trace("Downloading copilot-language-server with command: " .. cmd)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    logger.error("Error downloading file: " .. result)
    return false
  end

  -- Clean up cookie file
  if vim.fn.filereadable(cookie_file) == 1 then
    vim.fn.delete(cookie_file)
  end

  logger.debug("copilot-language-server downloaded to " .. local_server_zip_filepath)
  return true
end

---@param copilot_server_info copilot_server_info
---@param local_server_zip_filepath string
---@return boolean
local function extract_file(copilot_server_info, local_server_zip_filepath)
  if vim.fn.filereadable(local_server_zip_filepath) == 0 then
    logger.error("Error: file not found after download")
    return false
  end

  if vim.fn.filereadable(copilot_server_info.extracted_filename) == 1 then
    vim.fn.delete(copilot_server_info.extracted_filename)
  end

  local unzip_cmd
  if vim.fn.has("win32") > 0 then
    unzip_cmd = string.format(
      'powershell -Command "Expand-Archive -Path %s -DestinationPath %s"',
      local_server_zip_filepath,
      copilot_server_info.absolute_path
    )
  else
    unzip_cmd = string.format(
      "unzip -o %s -d %s",
      local_server_zip_filepath:gsub("\\", "\\\\"),
      copilot_server_info.absolute_path:gsub("\\", "\\\\")
    )
  end

  logger.trace("Extracting copilot-language-server with command: " .. unzip_cmd)
  vim.fn.system(unzip_cmd)

  if vim.v.shell_error ~= 0 then
    M.initialization_failed = true
    return false
  end

  vim.fn.delete(local_server_zip_filepath)
  vim.fn.rename(
    vim.fs.joinpath(copilot_server_info.absolute_path, copilot_server_info.extracted_filename),
    copilot_server_info.absolute_filepath
  )

  return true
end

---@param filename string
---@return boolean
local function set_permissions(filename)
  if vim.fn.has("win32") > 0 then
    return true
  end

  local chmod_cmd = string.format("chmod +x %s", filename)
  logger.trace("Setting permissions with command: " .. chmod_cmd)
  local result = vim.fn.system(chmod_cmd)

  if vim.v.shell_error ~= 0 then
    logger.error("Error setting permissions: " .. result)
    return false
  end

  return true
end

-- TODO: when this fails, it will cause a couple more errors before crashing
-- let's hope the naming convention does not change!!!
---@return boolean
function M.ensure_client_is_downloaded()
  if M.initialized then
    return true
  elseif M.initialization_failed then
    logger.error("copilot-language-server previously failed to initialize, please check the logs")
    return false
  end

  M.initialization_failed = true

  local copilot_version = util.get_editor_info().editorPluginInfo.version
  local plugin_path = vim.fs.normalize(util.get_plugin_path())
  local copilot_server_info = M.get_copilot_server_info(copilot_version, plugin_path)
  local download_filename =
    string.format("copilot-language-server-%s-%s.zip", copilot_server_info.path, copilot_version)
  local url = string.format(
    "https://github.com/github/copilot-language-server-release/releases/download/%s/%s",
    copilot_version,
    download_filename
  )
  local local_server_zip_path = vim.fs.joinpath(plugin_path, "copilot/", copilot_server_info.path)
  local local_server_zip_filepath =
    vim.fs.joinpath(plugin_path, "copilot/", copilot_server_info.path, download_filename)

  logger.trace("copilot_server_info: ", copilot_server_info)

  if vim.fn.filereadable(copilot_server_info.absolute_filepath) == 1 then
    logger.debug("copilot-language-server is already downloaded")
    M.initialization_failed = false
    return true
  end

  if not download_file(url, local_server_zip_filepath, local_server_zip_path) then
    return false
  end

  if not extract_file(copilot_server_info, local_server_zip_filepath) then
    return false
  end

  if not set_permissions(copilot_server_info.absolute_filepath) then
    logger.error("could not set permissions for copilot-language-server")
    return false
  end

  delete_all_except(copilot_server_info.absolute_path, copilot_server_info.filename)
  logger.notify("copilot-language-server downloaded")
  return true
end

---@return boolean
local function is_arm()
  local fh, err = assert(io.popen("uname -m 2>/dev/null", "r"))
  if err then
    logger.error("could not determine if cpu is arm, assuming it is not: " .. err)
    return false -- we assume not arm
  end

  local os_name
  if fh then
    os_name = fh:read()
    fh:close()
  end

  return os_name == "aarch64" or string.sub(os_name, 1, 3) == "arm"
end

---@return copilot_server_info
function M.get_copilot_server_info()
  if M.copilot_server_info then
    return M.copilot_server_info
  end

  local copilot_version = util.get_editor_info().editorPluginInfo.version
  local plugin_path = vim.fs.normalize(util.get_plugin_path())
  local path = ""
  local extracted_filename = "copilot-language-server"
  local filename = "copilot-language-server-" .. copilot_version
  local os = vim.loop.os_uname().sysname
  if os == "Linux" then
    if is_arm() then
      path = "linux-arm64"
    else
      path = "linux-x64"
    end
  elseif os == "Darwin" then
    if is_arm() then
      path = "darwin-arm64"
    else
      path = "darwin-x64"
    end
  elseif os == "Windows_NT" then
    path = "win32-x64"
    filename = filename .. ".exe"
    extracted_filename = extracted_filename .. ".exe"
  end

  if path == "" then
    logger.error("could not determine OS, please report this issue with the output of `uname -a`")
  end

  M.copilot_server_info = {
    path = path,
    filename = filename,
    absolute_path = vim.fs.joinpath(plugin_path, "copilot/", path),
    absolute_filepath = vim.fs.joinpath(plugin_path, "copilot/", path, filename),
    extracted_filename = extracted_filename,
  }

  return M.copilot_server_info
end

function M.setup(filepath)
  if not filepath then
    return M
  end

  if not vim.fn.filereadable(filepath) then
    logger.error("copilot-language-server not found at " .. filepath)
    return M
  end

  M.copilot_server_info = {
    path = "",
    filename = "",
    absolute_path = "",
    absolute_filepath = vim.fs.normalize(filepath),
    extracted_filename = "",
  }

  logger.debug("using custom copilot-language-server binary:", M.copilot_server_info.absolute_filepath)

  M.initialized = true
end

return M
